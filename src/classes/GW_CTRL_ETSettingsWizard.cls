public with sharing class GW_CTRL_ETSettingsWizard {

	// constructor	
	public GW_CTRL_ETSettingsWizard() {

        map<string, string> params = ApexPages.currentPage().getParameters();
        string str = params.get('currentTab');
        if (str != null && str != '') strCurrentTab = str;
		
	}
	
	public boolean inEditMode {
		get {
			return 
				ctabLevels.isEditingTab ||
				ctabGeneral.isEditingTab ||
				ctabDonor.isEditingTab ||
				ctabMember.isEditingTab ||
				ctabCampaign.isEditingTab ||
				ctabFrequency.isEditingTab ||
				ctabSchedule.isEditingTab ||
				ctabContact.isEditingTab ;
		}
		set;
	}
	
	public string strCurrentEditTab {
		get {
			if (ctabLevels.isEditingTab) return 'tabLevels';
			if (ctabGeneral.isEditingTab) return 'tabGeneral';
			if (ctabDonor.isEditingTab) return 'tabDonor';
			if (ctabContact.isEditingTab) return 'tabContact';
			if (ctabMember.isEditingTab) return 'tabMember';
			if (ctabCampaign.isEditingTab) return 'tabCampaign';
			if (ctabFrequency.isEditingTab) return 'tabFrequency';
			if (ctabSchedule.isEditingTab) return 'tabSchedule';
			return null;
		}
		set;
	}
	
	// tabPanel sets this thru an ajax call.
	public string strCurrentTab { get; set; }
	
	public EngagementTrackerSettings__c etSettings {
		get {
			if (etSettings == null) etSettings = GW_BATCH_EngagementRollup.settings;
			return etSettings;
		}
		set;
	}
	
	public GW_CTRL_ETSettingsTabLevels ctabLevels { 
		get {
			if (ctabLevels == null) ctabLevels = new GW_CTRL_ETSettingsTabLevels(this);
			return ctabLevels;
		}
		set;
	}
	
	public GW_CTRL_ETSettingsTabGeneral ctabGeneral { 
		get {
			if (ctabGeneral == null) ctabGeneral = new GW_CTRL_ETSettingsTabGeneral(this);
			return ctabGeneral;
		}
		set;
	}
	
	public GW_CTRL_ETSettingsTabContact ctabContact { 
		get {
			if (ctabContact == null) ctabContact = new GW_CTRL_ETSettingsTabContact(this);
			return ctabContact;
		}
		set;
	}
	
	public GW_CTRL_ETSettingsTabDonor ctabDonor { 
		get {
			if (ctabDonor == null) ctabDonor = new GW_CTRL_ETSettingsTabDonor(this); 
			return ctabDonor;
		}
		set;
	}
	
	public GW_CTRL_ETSettingsTabMember ctabMember { 
		get {
			if (ctabMember == null) ctabMember = new GW_CTRL_ETSettingsTabMember(this); 
			return ctabMember;
		}
		set;
	}

	public GW_CTRL_ETSettingsTabCampaign ctabCampaign { 
		get {
			if (ctabCampaign == null) ctabCampaign = new GW_CTRL_ETSettingsTabCampaign(this); 
			return ctabCampaign;
		}
		set;
	}

	public GW_CTRL_ETSettingsTabFrequency ctabFrequency { 
		get {
			if (ctabFrequency == null) ctabFrequency = new GW_CTRL_ETSettingsTabFrequency(this); 
			return ctabFrequency;
		}
		set;
	}

	public GW_CTRL_ETSettingsTabSchedule ctabSchedule { 
		get {
			if (ctabSchedule == null) ctabSchedule = new GW_CTRL_ETSettingsTabSchedule(this); 
			return ctabSchedule;
		}
		set;
	}

	// utility to create unique new names for the list of objects that don't have names.
	public void nameNewSettings(list<SObject> listSobj, string strPrefix) { 
		if (listSobj == null || strPrefix == null) return;
		
		// name new settings, by first finding the last name used.
		integer iUsedMax = 0;
		for (integer i = 0; i < listSobj.size(); i++ ) {
			string strName = string.valueOf(listSobj[i].get('name'));
			if (strName != null && strName.startsWith(strPrefix)) {
				integer iNum = integer.valueOf(strName.subString(strPrefix.length()));
				if (iNum > iUsedMax) {
					iUsedMax = iNum;
				}
			}
		}
		for (integer i = 0; i < listSobj.size(); i++ ) {
			if (listSobj[i].get('id') == null) {
				listSobj[i].put('name', strPrefix + string.valueOf(++iUsedMax));
			}
		}
	}
	
	// the list of Engagement Levels to put in the dropdowns
	public list<SelectOption> listSOLevels {
		get {
			if (listSOLevels == null) {
				list<SelectOption> listSO = new list<SelectOption>();
				listSO.add(new SelectOption('', ''));
				for (integer i = 1; i <= 8; i++) {
					string strLevel = 'Level_' + string.valueOf(i) + '_Name__c';
					string strLevelName = string.valueOf(etSettings.get(strLevel));
					if (strLevelName != null && strLevelName != '') {
						listSO.add(new SelectOption(string.valueOf(i) + '.0', strLevelName));
					}
				}
				listSOLevels = listSO;
			}		
			return listSOLevels;
		}
		set;
	}
	
	// set used to keep track of which contact fields are boolean, 
	// so we can automaticaly mark them as checkbox when saving Contact Field Settings.
	public set<string> setCheckboxFields { get; set; }
	
	// the list of Contact Fields to put in the dropdowns
	public list<SelectOption> listSOContactFields {
		get {
			if (listSOContactFields == null) {
				list<SelectOption> listSO = new list<SelectOption>();
				listSO.add(new SelectOption('', ''));				
				Map<String, Schema.SObjectField> mapS = Schema.SObjectType.Contact.fields.getMap();	
				
				// create temp list of strings to sort by alpha
				list<string> listStr = new list<string>();
				setCheckboxFields = new set<string>();
				for (Schema.SObjectField sf : mapS.values()) {
					Schema.DescribeFieldResult f = sf.getDescribe();
					listStr.add(f.Label + '.' + f.Name);
					if (f.Type == Schema.DisplayType.Boolean) {
						setCheckboxFields.add(f.Name);
					}
				}				
				listStr.sort();
				
				for (string str : listStr) {
					list<string> listPair = str.split('\\.');  // need to escape the dot char since this is regex
					listSO.add(new SelectOption(listPair[1], listPair[0]));					
				}				
							
				listSOContactFields = listSO;
			}		
			return listSOContactFields;
		}
		set;
	}
	
	// helper to say whether this instance has any campaign record types defined.
	// used by several tabs to hide a campaign record type column, when not needed.
	public boolean hasCampaignRecordTypes {
		get {
			return (listSOCampaignRecordTypes.size() > 1);
		}
	}
	
	// the list of Campaign Record Types to put in the dropdowns
	public list<SelectOption> listSOCampaignRecordTypes {
		get {
			if (listSOCampaignRecordTypes == null) {
				list<SelectOption> listSO = new list<SelectOption>();
				listSO.add(new SelectOption('', ''));				
				for (RecordType rt : [SELECT Name FROM RecordType WHERE SobjectType='Campaign']) {
					listSO.add(new SelectOption(rt.Name, rt.Name));	
				}
				listSOCampaignRecordTypes = listSO;
			}		
			return listSOCampaignRecordTypes;
		}
		set;
	}
	
	// the list of Campaign Types to put in the dropdowns
	public list<SelectOption> listSOCampaignTypes {
		get {
			if (listSOCampaignTypes == null) {
				list<SelectOption> listSO = new list<SelectOption>();
				listSO.add(new SelectOption('', ''));
				
				Schema.DescribeFieldResult F = Campaign.Type.getDescribe();
				for (Schema.PicklistEntry pe : F.getPicklistValues()) {
					listSO.add(new SelectOption(pe.Value, pe.Label));
				}
				listSOCampaignTypes = listSO;
			}		
			return listSOCampaignTypes;
		}
		set;
	}
	
	// the list of Campaign Sub Types to put in the dropdowns
	public list<SelectOption> listSOCampaignSubTypes {
		get {
			if (listSOCampaignSubTypes == null) {
				list<SelectOption> listSO = new list<SelectOption>();
				listSO.add(new SelectOption('', ''));
				
				if (GW_BATCH_EngagementRollup.IsGWBaseInstalled) {
					Map<String, Schema.SObjectField> M = Schema.SObjectType.Account.fields.getMap();									
					Schema.DescribeFieldResult F = M.get('GWBase__Campaign_Sub_Type__c').getDescribe();
					for (Schema.PicklistEntry pe : F.getPicklistValues()) {
						listSO.add(new SelectOption(pe.Value, pe.Label));
					}
				}
				
				listSOCampaignSubTypes = listSO;
			}		
			return listSOCampaignSubTypes;
		}
		set;
	}
	
	// helper used to hide Campaign Sub Type columns when not running with GWBase.
	public boolean IsGWBaseInstalled {
		get {
			return (GW_BATCH_EngagementRollup.IsGWBaseInstalled);
		}
	}
	
	//---------------------------------------- TEST CODE -------------------------------------------------
	static testmethod void TestWizard() {
		GW_CTRL_ETSettingsWizard ctrl = new GW_CTRL_ETSettingsWizard();
		system.assert(ctrl.ctabGeneral != null);
		system.assert(ctrl.ctabLevels != null);
		system.debug(ctrl.ctabGeneral);
		system.debug(ctrl.ctabLevels);
		system.assert(ctrl.inEditMode == false);
	}
}