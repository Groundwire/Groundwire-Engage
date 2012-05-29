public with sharing class GW_CTRL_ETSettingsTabGeneral {
	
	// constructor
	public GW_CTRL_ETSettingsTabGeneral(GW_CTRL_ETSettingsWizard cWiz) {
		ctrlWizard = cWiz;
		isEditingTab = false;
	}
	
	private GW_CTRL_ETSettingsWizard ctrlWizard { get; set; }

	public boolean isEditingTab { get; set; }
	
	public PageReference editTab() {
		isEditingTab = true;
		ctrlWizard.strCurrentTab = 'tabGeneral';
		return null;
	}
	
	public PageReference saveTab() {
		upsert ctrlWizard.etSettings;
		isEditingTab = false;
		ctrlWizard.strCurrentTab = 'tabGeneral';
		return null;
	}
	
	public PageReference cancelTab() {
		isEditingTab = false;
		ctrlWizard.etSettings = null;
		PageReference p = new PageReference('/apex/ETSettingsWizard?currentTab=tabGeneral' + ctrlWizard.strSalesforceTabNameParam);
		p.setRedirect(true);
		return p;
	}

	//---------------------------------------- TEST CODE -------------------------------------------------
	static testmethod void TestTabGeneral() {
		GW_CTRL_ETSettingsWizard ctrl = new GW_CTRL_ETSettingsWizard();
		system.assert(ctrl.ctabGeneral != null);
		system.assertEquals(ctrl.ctabGeneral.ctrlWizard, ctrl);
		system.assertEquals(ctrl.ctabGeneral.isEditingTab, false);
		system.assert(ctrl.ctabGeneral.ctrlWizard.etSettings != null);
		ctrl.ctabGeneral.editTab();
		system.assertEquals(ctrl.strCurrentEditTab, 'tabGeneral');
		ctrl.ctabGeneral.saveTab();
		system.assertEquals(ctrl.strCurrentEditTab, null);
		system.assert(ctrl.ctabGeneral.cancelTab() != null);		
	}


}