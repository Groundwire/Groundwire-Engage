public with sharing class GW_CTRL_ETSettingsTabLevels {
	
	// constructor
	public GW_CTRL_ETSettingsTabLevels(GW_CTRL_ETSettingsWizard cWiz) {
		ctrlWizard = cWiz;
		isEditingTab = false;
				
		// lookup values for engagement level picklist fields
		ReloadPicklistValues();		
	}

	private GW_CTRL_ETSettingsWizard ctrlWizard { get; set; }
	
	
	public EngagementTrackerSettings__c etSettings {
		get {
			if (etSettings == null) etSettings = GW_BATCH_EngagementRollup.settings;
			return etSettings;
		}
		set;
	}
	
	public boolean isEditingTab { get; set; }

	// strings for the four engagement level picklist fields
	private string strCELpicklist { get; set; }
	private string strCELOpicklist { get; set; }
	private string strCEPpicklist { get; set; }
	private string strCaELpicklist { get; set; }
	
	// strings lists for the four engagement level picklist fields
	public list<string> listStrCEL { get; set; }
	public list<string> listStrCELO { get; set; }
	public list<string> listStrCEP { get; set; }
	public list<string> listStrCaEL { get; set; }
	
	// using Describe, load up all the picklist values for the Engagement Level fields.
	private void ReloadPicklistValues() {
		
		strCELpicklist = '';	
		listStrCEL = new list<string>();
		for (Schema.PicklistEntry p : Contact.Engagement_Level__c.getDescribe().getPicklistValues()) {
			strCELpicklist += p.getLabel() + ';';			
			listStrCEL.add(p.getLabel());		
		}		

		strCELOpicklist = '';	
		listStrCELO = new list<string>();
		for (Schema.PicklistEntry p : Contact.Engagement_Level_Override__c.getDescribe().getPicklistValues()) {
			strCELOpicklist += p.getLabel() + ';';	
			listStrCELO.add(p.getLabel());		
		}		

		strCEPpicklist = '';	
		listStrCEP = new list<string>();
		for (Schema.PicklistEntry p : Contact.Engagement_Peak__c.getDescribe().getPicklistValues()) {
			strCEPpicklist += p.getLabel() + ';';			
			listStrCEP.add(p.getLabel());		
		}		

		strCaELpicklist = '';	
		listStrCaEL = new list<string>();
		for (Schema.PicklistEntry p : Campaign.Leadership_Level__c.getDescribe().getPicklistValues()) {
			strCaELpicklist += p.getLabel() + ';';			
			listStrCaEL.add(p.getLabel());		
		}		
	}
	

	public boolean isMatchingPicklists {
		get {
			string strLevels = 
				StrNullSemi(etSettings.Level_1_Name__c) +
				StrNullSemi(etSettings.Level_2_Name__c) +
				StrNullSemi(etSettings.Level_3_Name__c) +
				StrNullSemi(etSettings.Level_4_Name__c) +
				StrNullSemi(etSettings.Level_5_Name__c) +
				StrNullSemi(etSettings.Level_6_Name__c) +
				StrNullSemi(etSettings.Level_7_Name__c) +
				StrNullSemi(etSettings.Level_8_Name__c) ;
			return (strLevels == strCELpicklist &&
					strLevels == strCELOpicklist &&
					strLevels == strCEPpicklist &&
					strLevels == strCaELpicklist);
		}
	}
	
	private string StrNullSemi(string str) {
		if (str == null || str == '') return '';
		return str + ';';
	}
	
	public PageReference RetestPicklists() {
		ReloadPicklistValues();
		return null;	
	}
	
	public PageReference editTab() {
		isEditingTab = true;
		ctrlWizard.strCurrentTab = 'tabLevels';		
		return null;
	}
	
	public PageReference saveTab() {
		upsert etSettings;
		ctrlWizard.listSOLevels = null; // force them to reload
		isEditingTab = false;
		ctrlWizard.strCurrentTab = 'tabLevels';
		return null;
	}
	
	public PageReference cancelTab() {
		isEditingTab = false;
		etSettings = null;
		PageReference p = new PageReference('/apex/ETSettingsWizard?currentTab=tablevels');
		p.setRedirect(true);
		return p;
	}

}