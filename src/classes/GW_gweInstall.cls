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
	
	global void onInstall (InstallContext context) {
		defaultSettingsRec();
	}
	
	
	public void defaultSettingsRec() {
		// create a default general custom settings record if it's blank
		id orgId = UserInfo.getOrganizationId();
		if (EngagementTrackerSettings__c.getValues(orgId) == null) {
			EngagementTrackerSettings__c settings = new EngagementTrackerSettings__c();
			
			// set default levels
			// for now, use settings wiz controllers to fetch levels from the picklists
			// GW_CTRL_ETSettingsWizard wiz = new GW_CTRL_ETSettingsWizard();
			
			/* commented out for now - testing just using defaults for the levels instead of inspecting picklists
			GW_CTRL_ETSettingsTabLevels lvlsCTRL = new GW_CTRL_ETSettingsTabLevels();
			settings = lvlsCTRL.setDefaultLevels(settings);

			*/

			insert settings;			

		}		
	} 
	
	
	static testmethod void testIt() {
		GW_gweInstall script = new GW_gweInstall();
		script.defaultSettingsRec(); 
	}
	
	static testmethod void testItAsInstall() {
		GW_gweInstall script = new GW_gweInstall();
		// Test.testInstall (script,new Version(1,3));
		Test.testInstall (script,system.requestVersion());
		
		EngagementTrackerSettings__c settingsrecPostTest = EngagementTrackerSettings__c.getOrgDefaults();
		system.debug(loggingLevel.WARN,'settings rec post test: ' + settingsrecPostTest);
		
	}

}