public with sharing class GW_CTRL_ETSettingsTabSchedule {
	
	// constructor
	public GW_CTRL_ETSettingsTabSchedule(GW_CTRL_ETSettingsWizard cWiz) {
		ctrlWizard = cWiz;
		isEditingTab = false;
	}
	
	private GW_CTRL_ETSettingsWizard ctrlWizard { get; set; }

	public boolean isEditingTab { get; set; }
	
	public PageReference editTab() {
		isEditingTab = true;
		ctrlWizard.strCurrentTab = 'tabSchedule';
		return null;
	}
	
	public PageReference saveTab() {
		isEditingTab = false;
		ctrlWizard.strCurrentTab = 'tabSchedule';
		return null;
	}
	
	public PageReference cancelTab() {
		isEditingTab = false;
		PageReference p = new PageReference('/apex/ETSettingsWizard?currentTab=tabSchedule');
		p.setRedirect(true);
		return p;
	}
	
	public string jobId { get; set; }
	
	public PageReference ScheduleIt() {
        String strSch = '0 0 2 ? * Sun-Sat';	// run every day at 2am.
        GW_BATCH_EngagementRollup cls = new GW_BATCH_EngagementRollup();
        try {
        	jobId = system.schedule('Scheduled Engagement Rollup', strSch, cls);
        } catch (exception ex) {
        	ApexPages.addMessages(ex);
        }	
		ctrlWizard.strCurrentTab = 'tabSchedule';
        return null;	
	}

}