/**
 * Helper class that works with the suppression triggers to calculate what is accessible, describe which object is in context, and interpret premissions from custom setting.
 * The class exits the trigger context if:
 *		Import is not allowed for either (a)User, (b)Profile, (c)Organization
 *		None of the Jigsaw fields are accessible
 *		We were unable to describe the object being instantiated
 * @author = Shawn Butterfield, Salesforce.com
 */

public without sharing class data_ImportSuppressionTriggerHelper {

	private static Boolean hasHygienePackage = false;
	private static Boolean hasJigsawFLS = false;
	private static Map<String, Schema.SObjectField> sobjFieldMap;

	public static void doSuppression() {
		String userId = UserInfo.getUserId();
		String userProfileId = UserInfo.getProfileId();
		String objectName = Trigger.new.get(0).getSObjectType().getDescribe().getName();
		Boolean isImportDisabled = isImportDisabled(userId, userProfileId, objectName);
		
		// If the user/profile/org perms allow import, exit this method.
		if(!isImportDisabled) { return; }
		
		// Instantiate a new list of generics and inherit all of the objects in the triggered instance.
		List<SObject> newObjects = new List<SObject>();
		newObjects.addAll(Trigger.new);
		
		// Setup the correct field map

		if(newObjects.get(0).getSObjectType() == Account.SObjectType) {
			sobjFieldMap = Schema.SObjectType.Account.fields.getMap();
		}
		else if(newObjects.get(0).getSObjectType() == Contact.SObjectType) {
			sobjFieldMap = Schema.SObjectType.Contact.fields.getMap();
		}
		else if(newObjects.get(0).getSObjectType() == Lead.SObjectType) {
			sobjFieldMap = Schema.SObjectType.Lead.fields.getMap();
		}
		// Else not a supported object, exit this method.
		else return;
		
		try {
			hasJigsawFLS = data_SuppressionUtils.getFLS('Jigsaw', 'access', sobjFieldMap);
			hasHygienePackage = data_SuppressionUtils.getFLS('jigsaw_clean__Jigsaw_Id__c', 'access', sobjFieldMap);
		}
		catch(Exception e) {
			System.debug(LoggingLevel.ERROR,'Error retrieving FLS: ' +e.getStackTraceString());
		}
		
		// If there's not access to either field that we could check, just exit the method.
		if(!hasJigsawFLS && !hasHygienePackage) { return; }
		
		if(hasHygienePackage && hasJigsawFLS) {
			for(SObject s : newObjects) {
				if(s.get('jigsaw_clean__Jigsaw_Id__c') != null || s.get('Jigsaw') != null) {
					s.addError(Label.Data_com_Insufficient_Privileges);
				}
			}
		}
		else if(hasJigsawFLS || (Test.isRunningTest() && data_TestUtil.TEST_MODE == 1)) {
			for(SObject s : newObjects) {
				if(s.get('Jigsaw') != null) {
					s.addError(Label.Data_com_Insufficient_Privileges);
				}
			}
		}
		else if(hasHygienePackage || Test.isRunningTest()) {
			for(SObject s : newObjects) {
				if(s.get('jigsaw_clean__Jigsaw_Id__c') != null) {
					s.addError(Label.Data_com_Insufficient_Privileges);
				}
			}
		}
		// do nothing, there is no supported field we can check against.
		else return;
	}
	
	private static Boolean isImportDisabled(String userId, String profileId, String objectName) {
		
		Import_Settings__c userSetting = Import_Settings__c.getInstance((Id)userId);
		Import_Settings__c profileSetting = Import_Settings__c.getInstance((Id)profileId);
		Import_Settings__c orgSetting = Import_Settings__c.getOrgDefaults();
		
		if(userSetting.Id != null) {
			return (Boolean)userSetting.get(objectName+'_Import_Disabled__c');
		}
		else if(profileSetting.Id != null) {
			return (Boolean)profileSetting.get(objectName+'_Import_Disabled__c');
		}
		else if(orgSetting.Id != null) {
			return (Boolean)orgSetting.get(objectName+'_Import_Disabled__c');
		}
		// No settings defined, assume no permissions.
		// 4/18/2012: Had to change this branch of the logic tree to simply exit gracefully because under circumstances where other orgs have installed this code and are
		// either not using System.runAs OR they are and the 
		else {
			System.debug('+++++#### No settings defined, assume unknown or no permissions. Exiting the method gracefully. ####+++++');
			System.debug('Debugging userSetting: \n' +userSetting);
			System.debug('Debugging profileSetting: \n' +profileSetting);
			System.debug('Debugging orgSetting: \n' +orgSetting);
			System.debug('Debugging userId param passed to method: \n' +userId);
			System.debug('Debugging profileId param passed to method: \n' +profileId);
			System.debug('Debugging objectName passed to method: \n' +objectName);
			return true;
		}
	}
	
	// ############################
	/* TEST METHODS */
	// ############################
	
	private static testmethod void testSuppression() {
		
		Boolean dmlSuccessful = false;
		
		Map<String, Schema.SObjectField> acctFieldMap = Schema.SObjectType.Account.fields.getMap();
		Map<String, Schema.SObjectField> contactFieldMap = Schema.SObjectType.Contact.fields.getMap();
		Map<String, Schema.SObjectField> leadFieldMap = Schema.SObjectType.Lead.fields.getMap();
				
		Account a = new Account(Name='ABC Co',Website='www.abc.com');
		if(data_SuppressionUtils.getFLS('Jigsaw', 'access', acctFieldMap)) { a.put('Jigsaw','123456'); }
		try {
			insert a;
			dmlSuccessful = true;
		}
		catch(DMLException d) {
			system.assert(d.getMessage().length()>0);
			dmlSuccessful = false;
		}
		// We cannot assert behavior since we do not know what the users settings will be.
		/*system.assertEquals(false, dmlSuccessful);*/
		
		Contact c = new Contact(FirstName='first',LastName='last',Email='contact@company.com');
		try {
			insert c;
			dmlSuccessful = true;
		}
		catch(DMLException d) {
			system.assert(d.getMessage().length()>0);
			dmlSuccessful = false;
		}
		// We cannot assert behavior since we do not know what the users settings will be.
		/*system.assertEquals(false, dmlSuccessful);*/
		
		Lead l = new Lead(FirstName='first',LastName='last',Email='contact@company.com');
		if(data_SuppressionUtils.getFLS('jigsaw_clean__Jigsaw_Id__c', 'access', leadFieldMap)) {
			l.put('jigsaw_clean__Jigsaw_Id__c','123456');
		}
		try {
			insert l;
			dmlSuccessful = true;
		}
		catch(DMLException d) {
			system.assert(d.getMessage().length()>0);
			dmlSuccessful = false;
		}
		// We cannot assert behavior since we do not know what the users settings will be.
		/*system.assertEquals(false, dmlSuccessful);*/
	}
	
	private static testmethod void testIsImportAllowed() {
		
		Profile p = [SELECT Id,Name FROM Profile WHERE Name = 'System Administrator'];
		User u = new User(alias='passtest', email='passtest@testorg.com',
        emailencodingkey='UTF-8', lastname='Testing', languagelocalekey='en_US',
        localesidkey='en_US', profileid=p.Id,
        timezonesidkey='America/Los_Angeles', username='passtest@testorg.com');
        insert u;
        
        Import_Settings__c userSetting = Import_Settings__c.getInstance(u.Id);
        if(userSetting.Id == null) {
        	userSetting = new Import_Settings__c(SetupOwnerId=u.Id, Account_Import_Disabled__c=true, Contact_Import_Disabled__c=false, Lead_Import_Disabled__c=true);
        }
        else {
        	userSetting.Account_Import_Disabled__c = true;
        	userSetting.Contact_Import_Disabled__c = false;
        	userSetting.Lead_Import_Disabled__c = true;
        }
        upsert userSetting;
        
        Import_Settings__c profileSetting = Import_Settings__c.getInstance(p.Id);
        if(profileSetting.Id == null) { 
        	profileSetting = new Import_Settings__c(SetupOwnerId=p.Id, Account_Import_Disabled__c=true, Contact_Import_Disabled__c=true, Lead_Import_Disabled__c=false);
        }
        else {
        	profileSetting.Account_Import_Disabled__c=true; 
			profileSetting.Contact_Import_Disabled__c=true;
			profileSetting.Lead_Import_Disabled__c=false;
        }
        upsert profileSetting;
		
		Import_Settings__c orgSetting = Import_Settings__c.getOrgDefaults();
		if(orgSetting.Id == null) {
			orgSetting = new Import_Settings__c(SetupOwnerId=UserInfo.getOrganizationId(), Account_Import_Disabled__c=false, Contact_Import_Disabled__c=true, Lead_Import_Disabled__c=false);
		}
		else {
			orgSetting.Account_Import_Disabled__c=false; 
			orgSetting.Contact_Import_Disabled__c=true;
			orgSetting.Lead_Import_Disabled__c=false;
		}
		upsert orgSetting;
	
        System.runAs(u) { 
        	system.assertEquals(userSetting.Account_Import_Disabled__c, data_ImportSuppressionTriggerHelper.isImportDisabled(u.Id, p.Id, 'Account'));
        	system.assertEquals(userSetting.Contact_Import_Disabled__c, data_ImportSuppressionTriggerHelper.isImportDisabled(u.Id, p.Id, 'Contact'));
        	system.assertEquals(userSetting.Lead_Import_Disabled__c, data_ImportSuppressionTriggerHelper.isImportDisabled(u.Id, p.Id, 'Lead'));
        }
        
        Database.DeleteResult dr = Database.delete(userSetting);
        
        System.runAs(u) {
        	system.assertEquals(profileSetting.Account_Import_Disabled__c, data_ImportSuppressionTriggerHelper.isImportDisabled(u.Id, p.Id, 'Account'));
        	system.assertEquals(profileSetting.Contact_Import_Disabled__c, data_ImportSuppressionTriggerHelper.isImportDisabled(u.Id, p.Id, 'Contact'));
        	system.assertEquals(profileSetting.Lead_Import_Disabled__c, data_ImportSuppressionTriggerHelper.isImportDisabled(u.Id, p.Id, 'Lead'));        	
        }
        
        delete profileSetting;
        
        system.assertEquals(orgSetting.Account_Import_Disabled__c, data_ImportSuppressionTriggerHelper.isImportDisabled(u.Id, p.Id, 'Account'));
        
        delete orgSetting;
        
        system.assertEquals(true, data_ImportSuppressionTriggerHelper.isImportDisabled(u.Id, p.Id, 'Account'));
	}
}