/**
 * An asset folder is a hierarchy of named storage locations for assets (see :doc:`/reference/presideobjects/asset`)
 */
component output="false" extends="preside.system.base.SystemPresideObject" displayName="Asset folder" feature="assetManager" {
	property name="label" uniqueindexes="folderName|2";
	property name="original_label"       type="string"  dbtype="varchar" maxLength=200 required=false;
	property name="allowed_filetypes"    type="string"  dbtype="text"                  required=false;
	property name="max_filesize_in_mb"   type="numeric" dbtype="float"                 required=false maxValue=1000000;
	property name="access_restriction"   type="string"  dbtype="varchar" maxLength="7" required=false default="inherit" format="regex:(inherit|none|full)"  control="select" values="inherit,none,full" labels="preside-objects.asset_folder:access_restriction.option.inherit,preside-objects.asset_folder:access_restriction.option.none,preside-objects.asset_folder:access_restriction.option.full";
	property name="full_login_required"  type="boolean" dbtype="boolean"               required=false default=false;
	property name="is_system_folder"     type="boolean" dbtype="boolean"               required=false default=false;
	property name="system_folder_key"    type="string"  dbtype="varchar" maxLength=200 required=false indexes="systemfolderkey";
	property name="hidden"               type="boolean" dbtype="boolean"               required=false default=false;

	property name="parent_folder" relationship="many-to-one" relatedTo="asset_folder" required="false" uniqueindexes="folderName|1";

	property name="created_by"  relationship="many-to-one" relatedTo="security_user" required="false" generator="loggedInUserId";
	property name="updated_by"  relationship="many-to-one" relatedTo="security_user" required="false" generator="loggedInUserId";
}