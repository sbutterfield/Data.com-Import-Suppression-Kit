/**
 * Utilities class contains methods that are used multiple times across the same namespace or extension namespaces.
 * All methods and properties are Class level properties and publicly accessible.
 * @author = Shawn Butterfield, Salesforce.com
 */

public class data_SuppressionUtils {

	public static final String REGEX_EMAIL = '[\\w-]+@([\\w-]+\\.)+[\\w-]+';
	public static final String REGEX_PERSON_NAME = '^[a-zA-Z][a-zA-Z\\-\\\' ]*[a-zA-Z ]$';

	/**
	 * Used to check if the input email is formatted like a typical email address:
	 * asdf@asdf.com | asdf.323asdf@asdf134.co.uk
	 * @param email = the email address to match
	 * @return Boolean result = always return false unless matches
	 */
	public static Boolean matchesEmail(String email) {
		Boolean result = false;
		
		if(email == '' || email == null) {
			return false;
		}
		
		try {
			result = Pattern.matches(REGEX_EMAIL, email);
		}
		catch(Exception e) {
			system.debug(LoggingLevel.INFO,'1.0859453220e-1 -------------> matchesEmail() threw error: ' +e);
			return false;
		}
		return result;
	}
	
	/**
	 * Used to check if the input string is formatted as a typical person's name would be:
	 * Pierre-Francis d'Astier de Weyergans-Migery|Jeanne d'Arc|Nicolas Sarkozy|Charles de Gaulle|Dominique Strauss-Kahn
	 * @param pName = the person name to match
	 * @return Boolean result = always return false unless matches
	 */
	public static Boolean matchesPersonName(String pName) {
		Boolean result = false;
		
		if(pName == '' || pName == null) {
			return false;
		}
		
		try {
			result = Pattern.matches(REGEX_PERSON_NAME, pName);
		}
		catch(Exception e) {
			system.debug(LoggingLevel.INFO,'1.4254721420e+0 -------------> matchesPersonName() threw error: ' +e);
			return false;
		}
		return result;
	}

    /**
     * Method checks if the given profileId has the requested perm.
     * @param perm = the profile permission to check
     * @param profileId = the Id of the profile from the user making the request required by the perm
     * @return = a boolean response, true has perm, false does not
     */
    public static Boolean getProfilePerms(String perm, String profileId) {
        String queryString = 'SELECT p.Id, p.Name, p.' + perm + ' FROM Profile p WHERE p.Id = \'' + profileId + '\' LIMIT 1';
        List<Profile> resultset = new List<Profile>();
        
        try {
            resultset = Database.query(queryString);
        }
        catch (QueryException q) {
            System.debug(LoggingLevel.INFO,'-9.0537316420e-1 ------------------> A query exception ocurred: ' + q);
        }
        
        if (resultset == null || resultset.size() == 0) {
            return false;
        }
        
        Profile p = resultset.get(0);
        Boolean permVal = (Boolean) p.get(perm);
        System.debug('1.9314616130e+0 -------------------> Is the current accessor allowed to perform the requested action? : ' + permVal);
        return permVal;
    }
    
    /* Checks for fls in bulk by passing the field name and attempted action on the appropriate sobject */
    public static boolean getFLS(String fname, String action, Map<String, Schema.SObjectField> sobjFieldMap) {
        // Filter out bad parameters.
        if (sobjFieldMap == null) {
            return false;
        }
        
        Schema.SObjectField field = sobjFieldMap.get(fname);
        if (field == null) {
            return false;
        }
        
        Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
        if (fieldDescribe == null) {
            return false;
        }
        
        boolean flsResponse;
        if ('update'.equals(action)) {
            flsResponse = fieldDescribe.isUpdateable();
        }
        else if ('create'.equals(action)) {
            flsResponse = fieldDescribe.isCreateable();
        }
        else if ('access'.equals(action)) {
            flsResponse = fieldDescribe.isAccessible();
        }
        else if ('writeRequireMasterRead'.equals(action)){
            flsResponse = fieldDescribe.isWriteRequiresMasterRead();
        }
        else {
            flsResponse = false;
        }
        
        System.debug('The describe result from fls is: ' + flsResponse);
        return flsResponse;
    }

	
	// ############################
	/* TEST METHODS */
	// ############################

    private static testMethod void testGetFLS() {
        System.assertEquals(false, getFLS('bogus', 'bogus', null));
        
        Profile p = [select id from profile where name='Standard User'];
        User u = new User(alias='passtest', email='passtest@testorg.com',
            emailencodingkey='UTF-8', lastname='Testing', languagelocalekey='en_US',
            localesidkey='en_US', profileid=p.Id,
            timezonesidkey='America/Los_Angeles', username='passtest@testorg.com');
        System.runAs(u) {
            Map<String, Schema.sObjectField> sobjFieldMap = Schema.SObjectType.Account.fields.getMap();
            System.assertEquals(false, getFLS('bogus', 'bogus',  sobjFieldMap));
            System.assertEquals(false, getFLS('Phone', 'bogus',  sobjFieldMap));
            System.assertEquals(true,  getFLS('Phone', 'update', sobjFieldMap));
            System.assertEquals(true,  getFLS('Phone', 'create', sobjFieldMap));
            System.assertEquals(true,  getFLS('Phone', 'access', sobjFieldMap));
            System.assertEquals(false, getFLS('Phone', 'writeRequireMasterRead', sobjFieldMap));
        }
    }
    
    private static testMethod void testGetProfilePerms() {
        // Read Only profile should not have access to customize application.
        Profile p = [select id from profile where name='Read Only']; 
        System.assertEquals(false, getProfilePerms('PermissionsCustomizeApplication', p.Id));
        
        // System Administrator profile should have access to customize application.
        p = [select id from profile where name='System Administrator']; 
        System.assertEquals(true, getProfilePerms('PermissionsCustomizeApplication', p.Id));
        
        // Invalid profile should not have access to anything.
        p = new Profile();
        System.assertEquals(false, getProfilePerms('PermissionsCustomizeApplication', p.Id));
    }
    
    private static testMethod void testMatchers() {
    	String personName = 'person name-format';
    	String email = 'filast@company.com';
    	
    	Boolean matches = matchesEmail(email);
    	system.assert(matches);
    	
    	matches = matchesPersonName(personName);
    	system.assert(matches);
    	
    	// Non person name and email strings testing antipattern
    	personName = 'iiii|-1';
    	email = '1.2./?a.b.c@-1i39f*$li@!';
    	
    	matches = matchesEmail(email);
    	system.assert(!matches);
    	
    	matches = matchesPersonName(personName);
    	system.assert(!matches);
    }
}