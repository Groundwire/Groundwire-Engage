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

}