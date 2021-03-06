component output=false singleton=true implements="preside.system.services.fileStorage.StorageProvider" {

// CONSTRUCTOR
	public any function init( required string rootDirectory, required string trashDirectory, required string rootUrl ){
		_setRootDirectory( arguments.rootDirectory );
		_setTrashDirectory( arguments.trashDirectory );
		_setRootUrl( arguments.rootUrl );

		return this;
	}

// PUBLIC API METHODS
	public boolean function objectExists( required string path ){
		return FileExists( _expandPath( arguments.path ) );
	}

	public query function listObjects( required string path ){
		var cleanedPath = _cleanPath( arguments.path );
		var fullPath    = _expandPath( arguments.path );
		var objects     = QueryNew( "name,path,size,lastmodified" );
		var files       = "";

		if ( not DirectoryExists( fullPath ) ) {
			return objects;
		}

		files = DirectoryList( fullPath, false, "query" );
		for( var file in files ) {
			if ( file.type eq "File" ) {
				QueryAddRow( objects, {
					  name         = file.name
					, path         = "/" & cleanedPath & file.name
					, size         = file.size
					, lastmodified = file.datelastmodified
				} );
			}
		}

		return objects;
	}

	public binary function getObject( required string path ){
		try {
			return FileReadBinary( _expandPath( arguments.path ) );
		} catch ( java.io.FileNotFoundException e ) {
			throw(
				  type    = "storageProvider.objectNotFound"
				, message = "The object, [#arguments.path#], could not be found or is not accessible"
			);
		}
	}

	public struct function getObjectInfo( required string path ){
		try {
			var info = GetFileInfo( _expandPath( arguments.path ) );

			return {
				  size         = info.size
				, lastmodified = info.lastmodified
			};
		} catch ( any e ) {
			if ( e.message contains "not exist" ) {
				throw(
					  type    = "storageProvider.objectNotFound"
					, message = "The object, [#arguments.path#], could not be found or is not accessible"
				);
			}

			rethrow;
		}
	}

	public void function putObject( required any object, required string path ){
		var fullPath = _expandPath( arguments.path );

		if ( not IsBinary( arguments.object ) and not ( IsSimpleValue( arguments.object ) and FileExists( arguments.object ) ) ) {
			throw(
				  type    = "StorageProvider.invalidObject"
				, message = "The object argument passed to the putObject() method is invalid. Expected either a binary file object or valid file path but received [#SerializeJson( arguments.object )#]"
			);
		}

		_ensureDirectoryExist( GetDirectoryFromPath( fullPath ) );

		if ( IsBinary( arguments.object ) ) {
			FileWrite( fullPath, arguments.object );
		} else {
			FileCopy( arguments.object, fullPath );
		}
	}

	public void function deleteObject( required string path ){
		try {
			FileDelete( _expandPath( arguments.path ) );
		} catch ( any e ) {
			if ( e.message contains "does not exist" ) {
				return;
			}
			rethrow;
		}
	}

	public string function softDeleteObject( required string path ){
		var fullPath      = _expandPath( arguments.path );
		var newPath       = CreateUUId() & ".trash";
		var fullTrashPath = _getTrashDirectory() & newPath;

		try {
			FileMove( fullPath, fullTrashPath );
			return newPath;
		} catch ( any e ) {
			if ( e.message contains "does not exist" ) {
				return "";
			}

			rethrow;
		}
	}

	public boolean function restoreObject( required string trashedPath, required string newPath ){
		var fullTrashedPath   = _expandPath( arguments.trashedPath, _getTrashDirectory() );
		var fullNewPath       = _expandPath( arguments.newPath );
		var trashedFileExists = false;

		try {
			FileMove( fullTrashedPath, fullNewPath );
			return objectExists( arguments.newPath );
		} catch ( any e ) {
			if ( e.message contains "does not exist" ) {
				return false;
			}

			rethrow;
		}
	}

	public string function getObjectUrl( required string path ){
		return _getRootUrl() & _cleanPath( arguments.path );
	}

// PRIVATE HELPERS
	private string function _expandPath( required string path, string rootDir=_getRootDirectory() ){
		return arguments.rootDir & _cleanPath( arguments.path );
	}

	private string function _cleanPath( required string path ){
		var cleaned = ListChangeDelims( arguments.path, "/", "\" );

		cleaned = ReReplace( cleaned, "^/", "" );
		cleaned = Trim( cleaned );
		cleaned = LCase( cleaned );

		return cleaned;
	}

	private void function _ensureDirectoryExist( required string dir ){
		var parentDir = "";
		if ( not DirectoryExists( arguments.dir ) ) {
			parentDir = ListDeleteAt( arguments.dir, ListLen( arguments.dir, "/" ), "/" );
			_ensureDirectoryExist( parentDir );
			DirectoryCreate( arguments.dir );
		}
	}

// GETTERS AND SETTERS
	private string function _getRootDirectory(){
		return _rootDirectory;
	}
	private void function _setRootDirectory( required string rootDirectory ){
		_rootDirectory = arguments.rootDirectory;
		_rootDirectory = listChangeDelims( _rootDirectory, "/", "\" );
		if ( Right( _rootDirectory, 1 ) NEQ "/" ) {
			_rootDirectory &= "/";
		}
		_ensureDirectoryExist( _rootDirectory );
	}

	private string function _getTrashDirectory(){
		return _trashDirectory;
	}
	private void function _setTrashDirectory( required string trashDirectory ){
		_trashDirectory = arguments.trashDirectory;
		_trashDirectory = listChangeDelims( _trashDirectory, "/", "\" );
		if ( Right( _trashDirectory, 1 ) NEQ "/" ) {
			_trashDirectory &= "/";
		}

		_ensureDirectoryExist( _trashDirectory );
	}

	private string function _getRootUrl(){
		return _rootUrl;
	}
	private void function _setRootUrl( required string rootUrl ){
		_rootUrl = arguments.rootUrl;
		if ( Right( _rootUrl, 1 ) NEQ "/" ) {
			_rootUrl &= "/";
		}
	}
}