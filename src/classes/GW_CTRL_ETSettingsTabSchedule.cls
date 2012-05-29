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
		PageReference p = new PageReference('/apex/ETSettingsWizard?currentTab=tabSchedule' + ctrlWizard.strSalesforceTabNameParam);
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

	//---------------------------------------- TEST CODE -------------------------------------------------
	static testmethod void TestTabSchedule() {
		GW_CTRL_ETSettingsWizard ctrl = new GW_CTRL_ETSettingsWizard();
		system.assert(ctrl.ctabSchedule != null);
		system.assertEquals(ctrl.ctabSchedule.ctrlWizard, ctrl);
		system.assertEquals(ctrl.ctabSchedule.isEditingTab, false);
		system.assert(ctrl.ctabSchedule.ctrlWizard.etSettings != null);
		ctrl.ctabSchedule.editTab();
		system.assertEquals(ctrl.strCurrentEditTab, 'tabSchedule');
		ctrl.ctabSchedule.saveTab();
		system.assertEquals(ctrl.strCurrentEditTab, null);
		system.assert(ctrl.ctabSchedule.cancelTab() != null);	
		system.assert(ctrl.ctabSchedule.ScheduleIt() == null);	
	}


}