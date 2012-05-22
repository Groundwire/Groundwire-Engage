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
		PageReference p = new PageReference('/apex/ETSettingsWizard?currentTab=tabGeneral');
		p.setRedirect(true);
		return p;
	}


}