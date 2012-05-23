public with sharing class GW_CTRL_ETSettingsTabCampaign {

	// constructor
	public GW_CTRL_ETSettingsTabCampaign(GW_CTRL_ETSettingsWizard cWiz) {
		ctrlWizard = cWiz;
		isEditingTab = false;
	}
	
	private GW_CTRL_ETSettingsWizard ctrlWizard { get; set; }

    public List<EngagementCampaignSettings__c> listCampaignSettings {
    	get {
    		if (listCampaignSettings == null) {
    			listCampaignSettings = EngagementCampaignSettings__c.getall().values();    			
    			AddEmptyRows();
    		}
    		return listCampaignSettings;
    	}
    	set;
    }	

	public PageReference AddEmptyRows() {
		for (integer i = 0; i < 5; i++) {
			listCampaignSettings.add(new EngagementCampaignSettings__c());
		}
		return null;
	}	

	public boolean isEditingTab { get; set; }
	
	public PageReference editTab() {
		isEditingTab = true;
		ctrlWizard.strCurrentTab = 'tabCampaign';
		return null;
	}
	
	public PageReference saveTab() {
		list<EngagementCampaignSettings__c> listCStoDel = new list<EngagementCampaignSettings__c>();
		  
		// go thru the frequency settings, and delete empty ones
		for (integer i = listCampaignSettings.size()-1; i >= 0; i--) {
			EngagementCampaignSettings__c cs = listCampaignSettings[i];
			if (isnullNum(cs.Engagement_Level__c) && 
				isnullStr(cs.Campaign_Record_Type__c) &&
				isnullStr(cs.Campaign_Sub_Type__c) &&
				isnullStr(cs.Campaign_Type__c)) {
					if (cs.Id == null) {
						// it's a new empty dls; just remove it
						listCampaignSettings.remove(i);
					} else {
						// it's an existing, but cleared entry; delete it.
						listCampaignSettings.remove(i);
						listCStoDel.add(cs);
					}
			}
		}

		// name new settings
		ctrlWizard.nameNewSettings(listCampaignSettings, 'CampaignSetting');

		if (listCStoDel.size() > 0) delete listCStoDel;
		upsert listCampaignSettings;
		AddEmptyRows();
		
		// deal with etSettings.Levels_Don_t_Require_Responded__c
		upsert ctrlWizard.etSettings;
		
		isEditingTab = false;
		ctrlWizard.strCurrentTab = 'tabCampaign';
		return null;
	}
	
	public PageReference cancelTab() {
		isEditingTab = false;
		listCampaignSettings = null;
		ctrlWizard.etSettings = null;
		PageReference p = new PageReference('/apex/ETSettingsWizard?currentTab=tabCampaign');
		p.setRedirect(true);
		return p;
	}

	private boolean isnullStr(string str) {
		return (str == null || str == '');
	}

	private boolean isnullNum(decimal num) {
		return (num == null || num == 0);
	}
	
	private string strNoDotZero(string str) {
		if (str != null) {
			str = str.replace('.0', '');
		}
		return str;
	}

	// the list of Engagement Levels to put in the checkbox set
	public list<SelectOption> listSONonRespondedLevels {
		get {
			if (listSONonRespondedLevels == null) {
				listSONonRespondedLevels = new list<SelectOption>();
				
				for (SelectOption so : ctrlWizard.listSOLevels) {
					if (so.getLabel() != '') {
	    				listSONonRespondedLevels.add(new SelectOption(strNoDotZero(so.getValue()), so.getLabel()));
					}
    			}
			}		
			return listSONonRespondedLevels;
		}
		set;
	}
    
    public list<string> listNonRespondedLevels {
    	get {
    		list<string> listLevel = new list<string>();
    		if (ctrlWizard.etSettings.Levels_Don_t_Require_Responded__c != null) {
    			listLevel = ctrlWizard.etSettings.Levels_Don_t_Require_Responded__c.split(';');
    			
    			for (integer i = 0; i < listLevel.size(); i++) {
    				listLevel[i] = strNoDotZero(listLevel[i]);
    			}
    		}
    		return listLevel;
    	}
    	set { 
    		string strLevels = '';
    		for (string str : value) {
    			strLevels += strNoDotZero(str) + ';';
    		}
    		ctrlWizard.etSettings.Levels_Don_t_Require_Responded__c = strLevels;
    	}
    }
}