global class GW_gweInstall implements InstallHandler{
	
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
			GW_CTRL_ETSettingsTabLevels lvlsCTRL = new GW_CTRL_ETSettingsTabLevels();
			settings = lvlsCTRL.setDefaultLevels(settings);
			
			insert settings;
		}		
	} 

}