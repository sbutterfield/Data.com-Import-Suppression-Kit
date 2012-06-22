public with sharing class data_SuppressionConfigController {

    // global import accessors used to reflect current custom settings state
    public Boolean leadImportDisabled { get; set; }
    public Boolean contactImportDisabled { get; set; }
    public Boolean acctImportDisabled { get; set; }

    // search dependent class accessors
    public List<data_ImportSetting> searchResults { get; set; }
    public Boolean hasResults { get; set; }
    public String searchTerm { get; set; }
    public Boolean searchError { get; set; }

    // hasAccess view controller param accessors
    // usersId is used to query for permissions and determine access
    private String usersId { get; set; }
    private Boolean hasAccess = false;
    // static initializer from constructor instantiation
    public Boolean getHasAccess() {
        return this.hasAccess;
    }

    public data_SuppressionConfigController() {
        initPage();
        searchError = false;
    }
    
    /**
     * Initialize the page state. Checks profile permissions, throws error and does not allow page to render if user does not have perms.
     */
    private void initPage() {
        if(!data_SuppressionUtils.getProfilePerms('PermissionsManageUsers', UserInfo.getProfileId())) {
            ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.FATAL, (String)System.Label.Data_com_Insufficient_Privileges);
            ApexPages.addMessage(msg);
            hasAccess = false;
            return;
        }
        
        hasAccess = true;
        
        // Set initial Global Configuration Settings for the page.
        Import_Settings__c importSettings = Import_Settings__c.getOrgDefaults();
        if(importSettings != null) {
            this.acctImportDisabled = importSettings.Account_Import_Disabled__c;
            this.contactImportDisabled = importSettings.Contact_Import_Disabled__c;
            this.leadImportDisabled = importSettings.Lead_Import_Disabled__c;
        }
        else {
            // If the org defaults are not set, render false for inputs. DML will register this on [Save] action.
            this.acctImportDisabled = false;
            this.contactImportDisabled = false;
            this.leadImportDisabled = false;
        }
    }
    
    // ############################
    /* SEARCH LOGIC */
    // ############################

    public PageReference search() {
        initPage();
        if(searchTerm == '' || searchTerm == null) {
            this.searchResults = null;
            this.hasResults = false;
            searchError = true;
        }
        else {
            searchError = false;
            
            transient Boolean isEmail = data_SuppressionUtils.matchesEmail(searchTerm);
            transient Boolean isName = data_SuppressionUtils.matchesPersonName(searchTerm);
            transient String queryString = 'SELECT Id,Name ';
            User[] users;
            Profile[] profiles;

            if(isEmail) {
                // If the search term is formatted like an email, run a search accross email address or username
                queryString += ',ProfileId FROM User u WHERE u.Email LIKE \'%'+String.escapeSingleQuotes(searchTerm)+'%\' OR u.UserName LIKE \'%'+String.escapeSingleQuotes(searchTerm)+'%\'';
                users = doQuery(queryString);
            }
            else if(searchTerm == '*'){
                // Find all users and profiles
                queryString += ',ProfileId FROM User u';
                users = doQuery(queryString);
                queryString = 'SELECT Id,Name FROM Profile p';
                profiles = doQuery(queryString);
            }
            else {
                // Find potential user records
                queryString += ',ProfileId FROM User u WHERE u.Name LIKE \'%'+String.escapeSingleQuotes(searchTerm)+'%\'';
                users = doQuery(queryString);
                // Find potential profile records
                queryString =  'SELECT Id,Name FROM Profile p WHERE p.Name LIKE \'%'+String.escapeSingleQuotes(searchTerm)+'%\'';
                profiles = doQuery(queryString);
            }
            
            List<data_ImportSetting> settings = new List<data_ImportSetting>();
            if(users != null) {
                for(User u : users) {
                    // Instantiate new method objects and aliases
                    Import_Settings__c userSettings;
                    Import_Settings__c profileSettings;
                    data_ImportSetting thisSetting = new data_ImportSetting();
                    
                    try {
                        // Return current settings for the user, profile, and Org. If none exist a new instance is automatically created with a null Id for upsert.
                        userSettings = Import_Settings__c.getInstance(u.Id);
                        profileSettings = Import_Settings__c.getInstance(u.ProfileId);
                    }
                    catch(Exception e) {
                        system.debug(LoggingLevel.INFO,'1.9720446390e-1 ----------------> Did not fetch userSettings: ' +e);
                        ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.ERROR, '1.9720446390e-1 ----------------> Did not fetch userSettings: ' +e+ 
                        '\n' +userSettings+ 
                        '\n' +profileSettings);
                        ApexPages.addMessage(msg);
                    }
                    
                    // Now that we have an instance of the settings for the user, create a new apex object for serialization back to the View
                    // If the userSettings were inherited, check to see if there are specific settings for that user's profile and populate that instead
                    if(userSettings != null || profileSettings != null) {
                        thisSetting.sId = u.Id;
                        thisSetting.sPermId = userSettings.Id;
                        thisSetting.sType = 'User';
                        thisSetting.sName = u.Name;
                        // If the userSettings were inherited, check to see if there are specific settings for that user's profile and populate that instead
                        // Since the instance of userSettings will have the inherited permissions anyways, we dont have to worry about the logic to serialize "thisSetting" with profileSettings
                        thisSetting.sController = (userSettings.Id != null ? 'User Override' : profileSettings.Id != null ? 'Profile Override' : 'Org Default');
                        thisSetting.sAccountImportDisabled = userSettings.Account_Import_Disabled__c;
                        thisSetting.sContactImportDisabled = userSettings.Contact_Import_Disabled__c;
                        thisSetting.sLeadImportDisabled = userSettings.Lead_Import_Disabled__c;
                        settings.add(thisSetting);
                    }
                }
            }
            
            if(profiles != null) {
                for(Profile p : profiles) {
                    Import_Settings__c profileSettings;
                    
                    try {
                        //Return the current settings for the profile in the query result. If none exist a new instance is automatically created with a null Id for upsert.
                        profileSettings = Import_Settings__c.getInstance(p.Id);
                    }
                    catch(Exception e) {
                        system.debug(LoggingLevel.INFO,'-2.5418569590e-1 ----------------> Did not fetch profileSettings: ' +e);
                        ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.ERROR, '-2.5418569590e-1 ----------------> Did not fetch profileSettings: ' +e);
                        ApexPages.addMessage(msg);
                    }
                    
                    // Now that we have an instance of the settings for the profile, create a new apex object for serialization back to the View
                    if(profileSettings != null) {
                        data_ImportSetting thisSetting = new data_ImportSetting();
                        thisSetting.sId = p.Id;
                        thisSetting.sPermId = profileSettings.Id;
                        thisSetting.sType = 'Profile';
                        thisSetting.sName = p.Name;
                        thisSetting.sController = (profileSettings.Id == null ? 'Org Default' : 'Profile Override');
                        thisSetting.sAccountImportDisabled = profileSettings.Account_Import_Disabled__c;
                        thisSetting.sContactImportDisabled = profileSettings.Contact_Import_Disabled__c;
                        thisSetting.sLeadImportDisabled = profileSettings.Lead_Import_Disabled__c;
                        settings.add(thisSetting);
                    }
                }
            }
            
            if(settings.size() > 0) {
                this.hasResults = true;
                this.searchResults = settings;
            }
        }
        PageReference p = Page.data_SuppressionConfig;
        return p;
    }
    
    // ############################
    /* SAVE LOGIC */
    // ############################
    
    public PageReference saveConfig() {
        
        Import_Settings__c orgSettings = Import_Settings__c.getOrgDefaults();
        Boolean newSettings = false;
        
        if(orgSettings.Id == null) {
            // If there are no org settings, create some.
            orgSettings = new Import_Settings__c();
            // We need to know if we are creating a new instance of the settings to re-draw the view correctly if a searchResult is already part of the viewstate.
            newSettings = true;
        }
        
        Boolean globalChanged = false;
        if(orgSettings.Account_Import_Disabled__c != this.acctImportDisabled
        || orgSettings.Contact_Import_Disabled__c != this.contactImportDisabled
        || orgSettings.Lead_Import_Disabled__c != this.leadImportDisabled) {
            
            globalChanged = true;
        }
        
        if(globalChanged) {
	        orgSettings.Account_Import_Disabled__c = acctImportDisabled;
	        orgSettings.Contact_Import_Disabled__c = contactImportDisabled;
	        orgSettings.Lead_Import_Disabled__c = leadImportDisabled;
	        // Update-Insert the org-wide settings
	        upsert orgSettings;
        }
        
        if(searchResults != null && searchResults.size() > 0) {
            List<Import_Settings__c> settingsToDML = new List<Import_Settings__c>();
            // If there are search results from the page state, deserialize them and make any updates-inserts that are required
            for(data_ImportSetting s : searchResults) {
                // As long as these are not new org-wide settings, or the existing settings are not changing in this page state, evaluate the following:
                //      Have any of the fields on any of the ImportSettings objects changed in this viewstate? If yes - upsert those settings to the config : If not - that setting continues to inherit the org default
                if((!newSettings && !globalChanged) 
                && (s.getsAccountImportDisabled() != this.acctImportDisabled 
                || s.getsContactImportDisabled() != this.contactImportDisabled 
                || s.getsLeadImportDisabled() != this.leadImportDisabled)) {
                    Import_Settings__c thisSetting = Import_Settings__c.getInstance(s.getsId());
                    thisSetting.SetupOwnerId = s.getsId();
                    thisSetting.Account_Import_Disabled__c = s.getsAccountImportDisabled();
                    thisSetting.Contact_Import_Disabled__c = s.getsContactImportDisabled();
                    thisSetting.Lead_Import_Disabled__c = s.getsLeadImportDisabled();
                    settingsToDML.add(thisSetting);
                }
            }
            
            try {
                // attempt upsert - all or none is required for this operation.
                Database.upsert(settingsToDML, true);
            }
            catch(DMLException d) {
                system.debug(LoggingLevel.INFO,'3.3535892820e-2 -----------------> The controller was unable to upsert the Import Settings objcts: ' +d+ '\n These are the settings: ' +settingsToDML);
                ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.ERROR, '3.3535892820e-2 -----------------> The controller was unable to upsert the Import Settings objcts: ' +d+ '\n These are the settings: ' +settingsToDML);
                ApexPages.addMessage(msg);
            }
        }
        
        // Re-run the search if there is one so the user sees the changes go into effect immediately
        search();
        // Suppress any error on empty param
        this.searchError = false;
        // Re-draw the page from server
        PageReference p = Page.data_SuppressionConfig;        
        return p;
    }
    
    /**
     * Helper method for all queries from this page.
     * @param queryString = the string representation of a SOQL query
     * @return SObject[] = a collection of SObjects from the query result
     */
    private SObject[] doQuery(String queryString) {
        SObject[] result;
        try {
            result = Database.query(queryString);
        }
        catch(QueryException q) {
            system.debug(LoggingLevel.INFO,'1.1309009280e+0 ----------------> Query exception encountered: ' +q +'\n Original query string: ' +queryString);
            ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.ERROR, '1.1309009280e+0 ----------------> Query exception encountered: ' +q +'\n Original query string: ' +queryString);
            ApexPages.addMessage(msg);
        }
        return result;
    }
    
    // ############################
    /* TEST METHODS */
    // ############################
        
    private static testmethod void testController() {
         data_SuppressionConfigController c = new data_SuppressionConfigController();
         PageReference p = Page.data_SuppressionConfig;
         
         Boolean access = c.getHasAccess();
         system.assert(access);
         
         Import_Settings__c orgSetting = Import_Settings__c.getOrgDefaults();
         if(orgSetting.Id != null) {
            // Delete the org settings so that we can test the accessor page state and automatically creating a new org default on first save.
            delete orgSetting;
         }
         
         // Re-initialize the page state
         c.initPage();
         
         // Run a simple search, assert this does not throw an error back at the user.
         c.searchTerm = 'System Administrator';
         p = c.search();
         system.assert(c.hasResults);
         system.assert(!c.searchError);
         
         // Try a search for an email. This probably will not ever return a result.
         c.searchTerm = 'user@company.com';
         p = c.search();
         
         // Nill the searchTerm, re-run a search, this should throw an error.
         c.searchTerm = null;
         p = c.search();
         system.assert(c.searchError);
         
         // Now run a global search so we can assert that the user and profile collections both get populated
         c.searchTerm = '*';
         p = c.search();
         system.assert(!c.searchError);
         system.assert(c.hasResults);
         system.assert(c.searchResults.size()>0);
         
         // Update the org-wide config first, assert new values after page re-init()
         c.leadImportDisabled = false;
         c.contactImportDisabled = false;
         c.acctImportDisabled = false;
         p = c.saveConfig();
         // We shouldn't have a search error because the param is still stored in the controller
         system.assert(!c.searchError);
         system.assert(c.searchResults.size()>0);
         system.assert(!c.leadImportDisabled);
         system.assert(!c.contactImportDisabled);
         system.assert(!c.acctImportDisabled);
         
         // The page has been re-initialized with new global settings. Now let's make some changes to the users and profiles.
         for(data_ImportSetting s : c.searchResults) {
            s.setsAccountImportDisabled(true);
            s.setsContactImportDisabled(true);
            s.setsLeadImportDisabled(true);
         }
         c.saveConfig();
         
        system.assert(c.hasResults);
        system.debug(LoggingLevel.INFO,'Import Settings prior to testing: ' +c);
        for(data_ImportSetting s : c.searchResults) {
            system.assert(s.sAccountImportDisabled);
            system.assert(s.sContactImportDisabled);
            system.assert(s.sLeadImportDisabled);
            system.assertNotEquals(null, s.getsPermId());
            system.assertNotEquals(null, s.getsType());
            system.assertNotEquals(null, s.getsName());
            system.assertNotEquals(null, s.getsController());
        }
    }
}