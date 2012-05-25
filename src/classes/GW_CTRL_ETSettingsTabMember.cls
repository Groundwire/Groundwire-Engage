public with sharing class GW_CTRL_ETSettingsTabMember {

	// constructor
	public GW_CTRL_ETSettingsTabMember(GW_CTRL_ETSettingsWizard cWiz) {
		ctrlWizard = cWiz;
		isEditingTab = false;
	}
	
	private GW_CTRL_ETSettingsWizard ctrlWizard { get; set; }

	public boolean isEditingTab { get; set; }
	
	public PageReference editTab() {
		isEditingTab = true;
		ctrlWizard.strCurrentTab = 'tabMember';
		return null;
	}
	
	public PageReference saveTab() {
		upsert ctrlWizard.etSettings;
		isEditingTab = false;
		ctrlWizard.strCurrentTab = 'tabMember';
		return null;
	}
	
	public PageReference cancelTab() {
		isEditingTab = false;
		ctrlWizard.etSettings = null;
		PageReference p = new PageReference('/apex/ETSettingsWizard?currentTab=tabMember');
		p.setRedirect(true);
		return p;
	}
	
	//---------------------------------------- TEST CODE -------------------------------------------------
	static testmethod void TestTabMember() {
		GW_CTRL_ETSettingsWizard ctrl = new GW_CTRL_ETSettingsWizard();
		system.assert(ctrl.ctabMember != null);
		system.assertEquals(ctrl.ctabMember.ctrlWizard, ctrl);
		system.assertEquals(ctrl.ctabMember.isEditingTab, false);
		system.assert(ctrl.ctabMember.ctrlWizard.etSettings != null);
		ctrl.ctabMember.editTab();
		system.assertEquals(ctrl.strCurrentEditTab, 'tabMember');
		ctrl.ctabMember.saveTab();
		system.assertEquals(ctrl.strCurrentEditTab, null);
		system.assert(ctrl.ctabMember.cancelTab() != null);		
	}

}