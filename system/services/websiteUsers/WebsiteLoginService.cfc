/**
 * The website login manager object provides methods for member login, logout and session retrieval
 * \n
 * See also: :doc:`/devguides/websiteusers`
 */
component output=false singleton=true autodoc=true displayName="Website login service" {

// constructor
	/**
	 * @sessionService.inject             sessionService
	 * @cookieService.inject              cookieService
	 * @userDao.inject                    presidecms:object:website_user
	 * @userLoginTokenDao.inject          presidecms:object:website_user_login_token
	 * @bcryptService.inject              bcryptService
	 * @systemConfigurationService.inject systemConfigurationService
	 * @emailService.inject               emailService
	 */
	public any function init( required any sessionService, required any cookieService, required any userDao, required any userLoginTokenDao, required any bcryptService, required any systemConfigurationService, required any emailService ) output=false {
		_setSessionService( arguments.sessionService );
		_setCookieService( arguments.cookieService );
		_setUserDao( arguments.userDao );
		_setUserLoginTokenDao( arguments.userLoginTokenDao );
		_setBCryptService( arguments.bcryptService );
		_setSystemConfigurationService( arguments.systemConfigurationService );
		_setEmailService( arguments.emailService );
		_setSessionKey( "website_user" );
		_setRememberMeCookieKey( "_presidecms-site-persist" );

		return this;
	}

// public api methods

	/**
	 * Logs the user in by matching the passed login id against either the login id or email address
	 * fields and running a bcrypt password check to verify the security credentials. Returns true on success, false otherwise.
	 *
	 * @loginId.hint              Either the login id or email address of the user to login
	 * @password.hint             The password that the user has entered during login
	 * @rememberLogin.hint        Whether or not to set a "remember me" cookie
	 * @rememberExpiryInDays.hint When setting a remember me cookie, how long (in days) before the cookie should expire
	 *
	 */
	public boolean function login( required string loginId, string password="", boolean rememberLogin=false, rememberExpiryInDays=90, boolean skipPasswordCheck=false ) output=false autodoc=true {
		if ( !isLoggedIn() || isAutoLoggedIn() ) {
			var userRecord = _getUserByLoginId( arguments.loginId );

			if ( userRecord.count() && ( arguments.skipPasswordCheck || _validatePassword( arguments.password, userRecord.password ) ) ) {
				userRecord.session_authenticated = true;

				_setUserSession( userRecord );

				if ( arguments.rememberLogin ) {
					_setRememberMeCookie( userId=userRecord.id, loginId=userRecord.login_id, expiry=arguments.rememberExpiryInDays );
				}

				recordLogin();

				return true;
			}
		}

		return false;
	}

	/**
	 * Validates the supplied password against the a user (defaults to currently logged in user)
	 *
	 * @password.hint The user supplied password
	 * @userId.hint   The id of the user who's password we are to validate. Defaults to the currently logged in user.
	 *
	 */
	public boolean function validatePassword( required string password, string userId=getLoggedInUserId() ) output=false autodoc=true {
		var userRecord = _getUserDao().selectData( id=arguments.userId, selectFields=[ "password" ] );

		return userRecord.recordCount && _validatePassword( plainText=arguments.password, hashed=userRecord.password );
	}

	/**
	 * Logs the currently logged in user out of their session
	 *
	 */
	public void function logout() output=false autodoc=true {
		recordLogout();

		_getSessionService().deleteVar( name=_getSessionKey() );
		if ( _getCookieService().exists( _getRememberMeCookieKey() ) ) {
			var cookieValue = _readRememberMeCookie();
			_deleteRememberMeCookie();

			if ( Len( cookieValue.series ?: "" ) ) {
				_getUserLoginTokenDao().deleteData( filter={ series = cookieValue.series } );
			}
		}
	}

	/**
	 * Returns whether or not the user making the current request is logged in
	 * to the system.
	 *
	 * @securityAlertCallback.hint A function that will be invoked should their be a security alert during auto login checking. Use this to alert the user that their login may have been compromised.
	 */
	public boolean function isLoggedIn( function securityAlertCallback=function(){} ) output=false autodoc=true {
		var userSessionExists = _getSessionService().exists( name=_getSessionKey() );

		return userSessionExists || _autoLogin( argumentCollection = arguments );
	}

	/**
	 * Returns whether or not the user making the current request is only automatically logged in.
	 * This would happen when the user has been logged in via a "remember me" cookie. System's can
	 * make use of this method when protecting pages that require a full authenticated session, forcing
	 * a login prompt when this method returns true.
	 *
	 */
	public boolean function isAutoLoggedIn() output=false autodoc=true {
		return _getSessionService().exists( name=_getSessionKey() ) && !getLoggedInUserDetails().session_authenticated;
	}

	/**
	 * Returns the structure of user details belonging to the currently logged in user.
	 * If no user is logged in, an empty structure will be returned.
	 */
	public struct function getLoggedInUserDetails() output=false autodoc=true {
		var userDetails = _getSessionService().getVar( name=_getSessionKey(), default={} );

		return IsStruct( userDetails ) ? userDetails : {};
	}

	/**
	 * Returns the id of the currently logged in user, or an empty string if no user is logged in
	 */
	public string function getLoggedInUserId() output=false autodoc=true {
		var userDetails = getLoggedInUserDetails();

		return userDetails.id ?: "";
	}

	/**
	 * Sends welcome email to the supplied user. Returns true if successful, false otherwise.
	 *
	 * @loginId.hint The id of the user
	 */
	public boolean function sendWelcomeEmail( required string userId ) output=false autodoc=true {
		var userRecord = _getUserDao().selectData( id=arguments.userId );

		if ( userRecord.recordCount ) {
			var resetToken       = _createTemporaryResetToken();
			var resetKey         = _createTemporaryResetKey();
			var hashedResetKey   = _getBCryptService().hashPw( resetKey );
			var resetTokenExpiry = _createTemporaryResetTokenExpiry();

			_getUserDao().updateData( id=userRecord.id, data={
				  reset_password_token        = resetToken
				, reset_password_key          = hashedResetKey
				, reset_password_token_expiry = DateAdd( "d", 10000, Now() )
			} );

			_getEmailService().send(
				  template = "websiteWelcome"
				, to       = [ userRecord.email_address ]
				, args     = { resetToken = "#resetToken#-#resetKey#", expires=resetTokenExpiry, username=userRecord.display_name, loginid=userRecord.login_id }
			);

			return true;
		}

		return false;
	}

	/**
	 * Sends password reset instructions to the supplied user. Returns true if successful, false otherwise.
	 *
	 * @loginId.hint Either the email address or login id of the user
	 */
	public boolean function sendPasswordResetInstructions( required string loginId ) output=false autodoc=true {
		var userRecord = _getUserByLoginId( arguments.loginId );

		if ( userRecord.count() ) {
			var resetToken       = _createTemporaryResetToken();
			var resetKey         = _createTemporaryResetKey();
			var hashedResetKey   = _getBCryptService().hashPw( resetKey );
			var resetTokenExpiry = _createTemporaryResetTokenExpiry();

			_getUserDao().updateData( id=userRecord.id, data={
				  reset_password_token        = resetToken
				, reset_password_key          = hashedResetKey
				, reset_password_token_expiry = resetTokenExpiry
			} );

			_getEmailService().send(
				  template = "resetWebsitePassword"
				, to       = [ userRecord.email_address ]
				, args     = { resetToken = "#resetToken#-#resetKey#", expires=resetTokenExpiry, username=userRecord.display_name, loginId=userRecord.login_id }
			);

			return true;
		}

		return false;
	}

	/**
	 * Validates a password reset token that has been passed through the URL after
	 * a user has followed 'reset password' link in instructional email.
	 *
	 * @token.hint The token to validate
	 */
	public boolean function validateResetPasswordToken( required string token ) output=false autodoc=true {
		var record = _getUserRecordByPasswordResetToken( arguments.token );

		return record.recordCount == 1;
	}

	/**
	 * Resets a password by looking up the supplied password reset token and encrypting the supplied password
	 *
	 * @token.hint    The temporary reset password token to look the user up with
	 * @password.hint The new password
	 */
	public boolean function resetPassword( required string token, required string password ) output=false autodoc=true {
		var record = _getUserRecordByPasswordResetToken( arguments.token );

		if ( record.recordCount ) {
			var hashedPw = _getBCryptService().hashPw( password );

			return _getUserDao().updateData(
				  id   = record.id
				, data = { password=hashedPw, reset_password_token="", reset_password_key="", reset_password_token_expiry="" }
			);
		}
		return false;
	}

	/**
	 * Changes a password
	 *
	 * @password.hint The new password
	 * @userId.hint   ID of the user who's password we wish to change (defaults to currently logged in user id)
	 */
	public boolean function changePassword( required string password, string userId=getLoggedInUserId() ) output=false autodoc=true {
		var hashedPw = _getBCryptService().hashPw( arguments.password );

		return _getUserDao().updateData(
			  id   = arguments.userId
			, data = { password=hashedPw }
		);
	}

	/**
	 * Gets the post login URL for redirecting a user to after successful login
	 *
	 * @defaultValue.hint Value to use should there be no stored post login URL
	 *
	 */
	public string function getPostLoginUrl( required string defaultValue ) output=false {
		var sessionSavedValue = _getSessionService().getVar( "websitePostLoginUrl", "" );

		if ( Len( Trim( sessionSavedValue ) ) ) {
			return sessionSavedValue;
		}

		setPostLoginUrl( arguments.defaultValue );

		return arguments.defaultValue;
	}

	/**
	 * Sets the post login URL for redirecting a user to after successful login
	 *
	 * @postLoginUrl.hint URL to save
	 *
	 */
	public void function setPostLoginUrl( required string postLoginUrl ) output=false {
		_getSessionService().setVar( "websitePostLoginUrl", arguments.postLoginUrl );
	}

	/**
	 * Clears the post login URL from storage
	 *
	 */
	public boolean function clearPostLoginUrl() output=false {
		return _getSessionService().deleteVar( "websitePostLoginUrl" );
	}

	/**
	 * Gets an array of benefit IDs associated with the logged in user
	 *
	 */
	public array function listLoggedInUserBenefits() autodoc=true {
		var benefits = _getUserDao().selectData(
			  id           = getLoggedInUserId()
			, selectFields = [ "benefits.id" ]
			, forceJoins   = "inner"
		);

		return ValueArray( benefits.id );
	}

	/**
	 * Returns true / false depending on whether or not a user has access to any of the supplied benefits
	 *
	 * @benefits.hint Array of benefit IDs. If the logged in user has any of these benefits, the method will return true
	 *
	 */
	public boolean function doesLoggedInUserHaveBenefits( required array benefits ) autodoc=true {
		return _getUserDao().dataExists(
			filter = { "website_user.id"=getLoggedInUserId(), "benefits.id"=arguments.benefits }
		);
	}

	/**
	 * Sets the last logged in date for the logged in user
	 */
	public boolean function recordLogin() autodoc=true {
		var userId = getLoggedInUserId();

		return !Len( Trim( userId ) ) ? false : _getUserDao().updateData( id=userId, data={
			last_logged_in = Now()
		} );
	}

	/**
	 * Sets the last logged out date for the logged in user. Note, must be
	 * called before logging the user out
	 *
	 */
	public boolean function recordLogout() autodoc=true {
		var userId = getLoggedInUserId();

		return !Len( Trim( userId ) ) ? false : _getUserDao().updateData( id=userId, data={
			last_logged_out = Now()
		} );
	}

	/**
	 * Records the visit for the currently logged in user
	 * Currently, all this does is to set the last request made datetime value
	 *
	 */
	public boolean function recordVisit() autodoc=true {
		var userId = getLoggedInUserId();

		return !Len( Trim( userId ) ) ? false : _getUserDao().updateData( id=userId, data={
			last_request_made = Now()
		} );
	}

// private helpers
	private struct function _getUserByLoginId( required string loginId ) output=false {
		var record = _getUserDao().selectData(
			  filter       = "( login_id = :login_id or email_address = :login_id ) and active = 1"
			, filterParams = { login_id = arguments.loginId }
			, useCache     = false
		);

		for( var r in record ){
			return r;
		}

		return {};
	}

	private boolean function _validatePassword( required string plainText, required string hashed ) output=false {
		return _getBCryptService().checkPw( plainText=arguments.plainText, hashed=arguments.hashed );
	}

	private void function _setUserSession( required struct data ) output=false {
		_getSessionService().setVar( name=_getSessionKey(), value=arguments.data );
	}

	private void function _setRememberMeCookie( required string userId, required string loginId, required string expiry ) output=false {
		var cookieValue = {
			  loginId = arguments.loginId
			, expiry  = arguments.expiry
			, series  = _createNewLoginTokenSeries()
			, token   = _createNewLoginToken()
		};

		_getUserLoginTokenDao().insertData( data={
			  user   = arguments.userId
			, series = cookieValue.series
			, token  = _getBCryptService().hashPw( cookieValue.token )
		} );

		_getCookieService().setVar(
			  name     = _getRememberMeCookieKey()
			, value    = cookieValue
			, expires  = arguments.expiry
			, httpOnly = true
		);
	}

	private void function _deleteRememberMeCookie() output=false {
		_getCookieService().deleteVar( _getRememberMeCookieKey() );
	}

	private struct function _readRememberMeCookie() output=false {
		var cookieValue = _getCookieService().getVar( _getRememberMeCookieKey(), {} );

		if ( IsStruct( cookieValue ) ) {
			var keys = cookieValue.keyArray()
			keys.sort( "textNoCase" );

			if ( keys.toList() == "expiry,loginId,series,token" ) {
				return cookieValue;
			}
		}

		return {};
	}

	private boolean function _autoLogin( required function securityAlertCallback ) output=false {
		if ( StructKeyExists( request, "_presideWebsiteAutoLoginResult" ) ) {
			return request._presideWebsiteAutoLoginResult;
		}

		if ( _getCookieService().exists( _getRememberMeCookieKey() ) ) {
			var cookieValue = _readRememberMeCookie();
			var user        = _getUserRecordFromCookie( cookieValue, securityAlertCallback );

			if ( user.count() ) {
				user.session_authenticated = false;
				_setUserSession( user );

				request._presideWebsiteAutoLoginResult = true;
				return true;
			}

			_deleteRememberMeCookie();
		}

		request._presideWebsiteAutoLoginResult = false;
		return false;

	}

	private struct function _getUserRecordFromCookie( required struct cookieValue, required function securityAlertCallback ) output=false {
		if ( StructCount( arguments.cookieValue ) ) {
			var tokenRecord = _getUserLoginTokenDao().selectData(
				  selectFields = [ "website_user_login_token.id", "website_user_login_token.token", "website_user.login_id" ]
				, filter       = { series = arguments.cookieValue.series }
			);

			if ( tokenRecord.recordCount && tokenRecord.login_id == arguments.cookieValue.loginId ) {
				if ( _getBCryptService().checkPw( arguments.cookieValue.token, tokenRecord.token ) ) {
					_recycleLoginToken( tokenRecord.id, arguments.cookieValue );
					return _getUserByLoginId( tokenRecord.login_id );
				}

				_getUserLoginTokenDao().deleteData( id=tokenRecord.id );
				securityAlertCallback();
			}
		}

		return {};
	}

	private void function _recycleLoginToken( required string tokenId, required struct cookieValue ) output=false {
		arguments.cookieValue.token = _createNewLoginToken();

		_getUserLoginTokenDao().updateData(
			  id   = arguments.tokenId
			, data = { token = _getBCryptService().hashPw( arguments.cookieValue.token )
		} );

		_getCookieService().setVar(
			  name     = _getRememberMeCookieKey()
			, value    = arguments.cookieValue
			, expires  = arguments.cookieValue.expiry
			, httpOnly = true
		);
	}

	private string function _createNewLoginTokenSeries() output=false {
		return _createRandomToken();
	}

	private string function _createNewLoginToken() output=false {
		return _createRandomToken();
	}

	private string function _createTemporaryResetToken() output=false {
		return _createRandomToken();
	}

	private string function _createTemporaryResetKey() output=false {
		return _createRandomToken();
	}

	private string function _createRandomToken() output=false {
		var chars    = ListToArray( Replace( CreateUUId(), "-", "", "all" ), "" );
		var token = "";

		while( chars.len() ){
			var position = RandRange( 1, chars.len(), "SHA1PRNG" );

			if ( RandRange( 1, 2, "SHA1PRNG" ) == 1 ) {
				token &= LCase( chars[ position ] );
			} else {
				token &= chars[ position ];
			}

			chars.deleteAt( position );
		}

		return token;
	}

	private date function _createTemporaryResetTokenExpiry() output=false {
		var expiry = Val( _getSystemConfigurationService().getSetting( "website_users", "reset_password_token_expiry", 60 ) );

		if ( !expiry ) {
			return DateAdd( "d", 10000, Now() );
		} else {
			return DateAdd( "n", expiry, Now() );
		}
	}

	private query function _getUserRecordByPasswordResetToken( required string token ) output=false {
		var t = ListFirst( arguments.token, "-" );
		var k = ListLast( arguments.token, "-" );

		var record = _getUserDao().selectData(
			  selectFields = [ "id", "reset_password_key", "reset_password_token_expiry" ]
			, filter       = { reset_password_token = t }
		);

		if ( !record.recordCount ) {
			return record;
		}

		if ( Now() > record.reset_password_token_expiry || !_getBCryptService().checkPw( k, record.reset_password_key ) ) {
			_getUserDao().updateData(
				  id     = record.id
				, data   = { reset_password_token="", reset_password_key="", reset_password_token_expiry="" }
			);

			return QueryNew('');
		}

		return record;
	}

// private accessors
	private any function _getSessionService() output=false {
		return _sessionService;
	}
	private void function _setSessionService( required any sessionService ) output=false {
		_sessionService = arguments.sessionService;
	}

	private any function _getCookieService() output=false {
		return _cookieService;
	}
	private void function _setCookieService( required any cookieService ) output=false {
		_cookieService = arguments.cookieService;
	}

	private any function _getUserDao() output=false {
		return _userDao;
	}
	private void function _setUserDao( required any userDao ) output=false {
		_userDao = arguments.userDao;
	}

	private any function _getBCryptService() output=false {
		return _bCryptService;
	}
	private void function _setBCryptService( required any bCryptService ) output=false {
		_bCryptService = arguments.bCryptService;
	}

	private string function _getSessionKey() output=false {
		return _sessionKey;
	}
	private void function _setSessionKey( required string sessionKey ) output=false {
		_sessionKey = arguments.sessionKey;
	}

	private string function _getRememberMeCookieKey() output=false {
		return _rememberMeCookieKey;
	}
	private void function _setRememberMeCookieKey( required string rememberMeCookieKey ) output=false {
		_rememberMeCookieKey = arguments.rememberMeCookieKey;
	}

	private any function _getUserLoginTokenDao() output=false {
		return _userLoginTokenDao;
	}
	private void function _setUserLoginTokenDao( required any userLoginTokenDao ) output=false {
		_userLoginTokenDao = arguments.userLoginTokenDao;
	}

	private any function _getSystemConfigurationService() output=false {
		return _systemConfigurationService;
	}
	private void function _setSystemConfigurationService( required any systemConfigurationService ) output=false {
		_systemConfigurationService = arguments.systemConfigurationService;
	}

	private any function _getEmailService() output=false {
		return _emailService;
	}
	private void function _setEmailService( required any emailService ) output=false {
		_emailService = arguments.emailService;
	}
}