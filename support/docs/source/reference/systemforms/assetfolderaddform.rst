Asset folder: add form
======================

*/forms/preside-objects/asset_folder/admin.add.xml*

This form is used for adding folders in the asset manager section of the administrator.

.. code-block:: xml

    <?xml version="1.0" encoding="UTF-8"?>

    <form>
        <tab id="basic" sortorder="10" title="preside-objects.asset_folder:basic.tab.title">
            <fieldset id="basic" sortorder="10">
                <field sortorder="10" binding="asset_folder.label" />
            </fieldset>
        </tab>
        <tab id="restrictions" sortorder="20" title="preside-objects.asset_folder:restrictions.tab.title">
            <fieldset id="restrictions" sortorder="10">
                <field sortorder="10" binding="asset_folder.allowed_filetypes" control="filetypepicker" multiple="true" />
                <field sortorder="20" binding="asset_folder.max_filesize_in_mb" />
            </fieldset>
        </tab>
        <tab id="permissions" sortorder="30" title="preside-objects.asset_folder:permissions.tab.title">
            <fieldset id="permissions" sortorder="10">
                <field sortorder="10" binding="asset_folder.access_restriction" />
                <field sortorder="20" binding="asset_folder.full_login_required" />
                <field sortorder="30" name="grant_access_to_benefits" control="objectPicker" object="website_benefit" multiple="true" required="false" label="preside-objects.asset_folder:field.grant_access_to_benefits.title" help="preside-objects.asset_folder:field.grant_access_to_benefits.help" />
                <field sortorder="40" name="deny_access_to_benefits"  control="objectPicker" object="website_benefit" multiple="true" required="false" label="preside-objects.asset_folder:field.deny_access_to_benefits.title"  help="preside-objects.asset_folder:field.deny_access_to_benefits.help"  />
                <field sortorder="50" name="grant_access_to_users"    control="objectPicker" object="website_user"    multiple="true" required="false" label="preside-objects.asset_folder:field.grant_access_to_users.title"    help="preside-objects.asset_folder:field.grant_access_to_users.help"    />
                <field sortorder="60" name="deny_access_to_users"     control="objectPicker" object="website_user"    multiple="true" required="false" label="preside-objects.asset_folder:field.deny_access_to_users.title"     help="preside-objects.asset_folder:field.deny_access_to_users.help"     />
            </fieldset>
        </tab>
    </form>

