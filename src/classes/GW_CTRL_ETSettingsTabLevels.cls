public with sharing class GW_CTRL_ETSettingsTabLevels {
	
	// constructor
	public GW_CTRL_ETSettingsTabLevels(GW_CTRL_ETSettingsWizard cWiz) {
		ctrlWizard = cWiz;
		isEditingTab = false;
				
		// lookup values for engagement level picklist fields
		ReloadPicklistValues();		
	}

	// alternate no-arg constructor for use from install script
	public GW_CTRL_ETSettingsTabLevels () {
		ReloadPicklistValues();		
	}

	private GW_CTRL_ETSettingsWizard ctrlWizard { get; set; }
	
	
	public EngagementTrackerSettings__c etSettings {
		get {
			if (etSettings == null) {
				etSettings = GW_BATCH_EngagementRollup.settings;
			}
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
	
	public EngagementTrackerSettings__c setDefaultLevels (EngagementTrackerSettings__c settings) {
		// first time through, if we are creating a settings rec, and all the picklist fields match, start w/ level names that match the picklists
		// we did the describe in the constructor, so the picklist data should be available when this is called
		if (strCELpicklist==strCELOpicklist && strCELOpicklist==strCEPpicklist && strCEPpicklist==strCaELpicklist && listStrCEL.size() > 0) {
			try {
				settings.Level_1_Name__c = listStrCEL[0];
				settings.Level_2_Name__c = listStrCEL[1];
				settings.Level_3_Name__c = listStrCEL[2];
				settings.Level_4_Name__c = listStrCEL[3];
				settings.Level_5_Name__c = listStrCEL[4];
				settings.Level_6_Name__c = listStrCEL[5];
				settings.Level_7_Name__c = listStrCEL[6];
				settings.Level_8_Name__c = listStrCEL[7];
			} catch(exception ex) {
			}
		}
		return settings;
	}
	
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
	
	private boolean isValidLevelNames() {
		return (
			(ctrlWizard.isnullStr(etSettings.Level_1_Name__c) || startsWithNumber(etSettings.Level_1_Name__c)) &&
			(ctrlWizard.isnullStr(etSettings.Level_2_Name__c) || startsWithNumber(etSettings.Level_2_Name__c)) &&
			(ctrlWizard.isnullStr(etSettings.Level_3_Name__c) || startsWithNumber(etSettings.Level_3_Name__c)) &&
			(ctrlWizard.isnullStr(etSettings.Level_4_Name__c) || startsWithNumber(etSettings.Level_4_Name__c)) &&
			(ctrlWizard.isnullStr(etSettings.Level_5_Name__c) || startsWithNumber(etSettings.Level_5_Name__c)) &&
			(ctrlWizard.isnullStr(etSettings.Level_6_Name__c) || startsWithNumber(etSettings.Level_6_Name__c)) &&
			(ctrlWizard.isnullStr(etSettings.Level_7_Name__c) || startsWithNumber(etSettings.Level_7_Name__c)) &&
			(ctrlWizard.isnullStr(etSettings.Level_8_Name__c) || startsWithNumber(etSettings.Level_8_Name__c)) );		
	}
	
	private boolean startsWithNumber(string str) {
		if (str == null || str == '') return false;
		try {
			integer i = integer.valueOf(str.substring(0,1));
			return true;
		} catch(exception ex) {
			return false;
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
		if (!isValidLevelNames()) {
        	ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, 'Engagement Level Names must start with a number from 1 to 8.'));
        	return null;			
		}
		upsert etSettings;
		ctrlWizard.listSOLevels = null; // force them to reload
		isEditingTab = false;
		ctrlWizard.strCurrentTab = 'tabLevels';
		return null;
	}
	
	public PageReference cancelTab() {
		isEditingTab = false;
		etSettings = null;
		PageReference p = new PageReference('/apex/ETSettingsWizard?currentTab=tablevels' + ctrlWizard.strSalesforceTabNameParam);
		p.setRedirect(true);
		return p;
	}

	//---------------------------------------- TEST CODE -------------------------------------------------
	static testmethod void TestTabLevels() {
		GW_CTRL_ETSettingsWizard ctrl = new GW_CTRL_ETSettingsWizard();
		system.assert(ctrl.ctabLevels != null);
		system.assertEquals(ctrl.ctabLevels.ctrlWizard, ctrl);
		system.assertEquals(ctrl.ctabLevels.etSettings, ctrl.etSettings);
		system.assertEquals(ctrl.ctabLevels.isEditingTab, false);
		system.assert(ctrl.ctabLevels.strCELpicklist != null);
		system.assert(ctrl.ctabLevels.strCELOpicklist != null);
		system.assert(ctrl.ctabLevels.strCEPpicklist != null);
		system.assert(ctrl.ctabLevels.strCaELpicklist != null);
		system.assert(ctrl.ctabLevels.listStrCEL != null);
		system.assert(ctrl.ctabLevels.listStrCELO != null);
		system.assert(ctrl.ctabLevels.listStrCEP != null);
		system.assert(ctrl.ctabLevels.listStrCaEL != null);
		system.assert(ctrl.ctabLevels.isMatchingPicklists == ctrl.ctabLevels.isMatchingPicklists);
		ctrl.ctabLevels.RetestPicklists();
		ctrl.ctabLevels.editTab();
		system.assertEquals(ctrl.strCurrentEditTab, 'tabLevels');
		ctrl.ctabLevels.saveTab();
		system.assertEquals(ctrl.strCurrentEditTab, null);
		system.assert(ctrl.ctabLevels.cancelTab() != null);
		
	}
}