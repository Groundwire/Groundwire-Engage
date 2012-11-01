global class GW_gweInstall implements InstallHandler{

/*******************************************************************************************************
* @author Matthew Scholtz
* @date 7/1/2012
* @description Install script for package, creates a default general settings rec
*
* Written by Matthew Scholtz, copyright (c) 2012 Groundwire
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
*/

	// install script for Groundwire Engage
	
	private InstallContext icontext;
	
	global void onInstall (InstallContext context) {
		this.icontext = context; 

		defaultSettingsRec();
		// defaultErrEmailAddy();   // called by the method above
	}
	
	
	public void defaultSettingsRec() {
		// create a default general custom settings record if it's blank
		id orgId = UserInfo.getOrganizationId();
		if (EngagementTrackerSettings__c.getValues(orgId) == null) {
			EngagementTrackerSettings__c settings = new EngagementTrackerSettings__c();
			try {
				insert settings;
				defaultErrEmailAddy();
			} catch (exception e){
				// nothing for now, just don't want install to fail
			}			

		}		
	} 
	
	public void defaultErrEmailAddy() {
		// set the "send error emails to" address to the installing user by default
		if (icontext != null) {
			User u = [SELECT Id,Email From User WHERE Id = :icontext.installerID() LIMIT 1];
			if (u != null) {
				EngagementTrackerSettings__c settings = EngagementTrackerSettings__c.getOrgDefaults();
				if (settings.Send_Error_Emails_To__c == null) {
					settings.Send_Error_Emails_To__c = u.Email;
					update settings;
				}
			}
		}
	}
	
	static testmethod void testIt() {
		GW_gweInstall script = new GW_gweInstall();
		script.defaultSettingsRec();
		script.defaultErrEmailAddy(); 
	}
	
	static testmethod void testItAsInstall() {
		GW_gweInstall script = new GW_gweInstall();
		// Test.testInstall (script,new Version(1,3));
		Test.testInstall (script,system.requestVersion());
		
		EngagementTrackerSettings__c settingsrecPostTest = EngagementTrackerSettings__c.getOrgDefaults();
		system.debug(loggingLevel.WARN,'settings rec post test: ' + settingsrecPostTest);
		
	}

}