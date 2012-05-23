public with sharing class GW_CTRL_ETSettingsTabFrequency {

	// constructor
	public GW_CTRL_ETSettingsTabFrequency(GW_CTRL_ETSettingsWizard cWiz) {
		ctrlWizard = cWiz;
		isEditingTab = false;
	}
	
	private GW_CTRL_ETSettingsWizard ctrlWizard { get; set; }
	
    public List<EngagementFrequencySettings__c> listFreqSettings {
    	get {
    		if (listFreqSettings == null) {
    			listFreqSettings = EngagementFrequencySettings__c.getall().values();    			
    			AddEmptyRows();
    		}
    		return listFreqSettings;
    	}
    	set;
    }	

	public PageReference AddEmptyRows() {
		for (integer i = 0; i < 5; i++) {
			listFreqSettings.add(new EngagementFrequencySettings__c());
		}
		return null;
	}	

	public boolean isEditingTab { get; set; }
	
	public PageReference editTab() {
		isEditingTab = true;
		ctrlWizard.strCurrentTab = 'tabFrequency';
		return null;
	}
	
	public PageReference saveTab() {
		list<EngagementFrequencySettings__c> listFStoDel = new list<EngagementFrequencySettings__c>();
		  
		// go thru the frequency settings, and delete empty ones
		for (integer i = listFreqSettings.size()-1; i >= 0; i--) {
			EngagementFrequencySettings__c fs = listFreqSettings[i];
			if (isnullStr(fs.Fieldname_1__c) && 
				isnullStr(fs.Campaign_Record_Type__c) &&
				isnullStr(fs.Campaign_Sub_Type__c) &&
				isnullStr(fs.Campaign_Type__c) &&
				isnullStr(fs.Field_Value_1__c) &&
				isnullNum(fs.Level_Required__c) &&
				isnullNum(fs.Level_To_Assign__c) &&
				isnullNum(fs.Number_of_Actions_Required__c)) {
					if (fs.Id == null) {
						// it's a new empty dls; just remove it
						listFreqSettings.remove(i);
					} else {
						// it's an existing, but cleared entry; delete it.
						listFreqSettings.remove(i);
						listFStoDel.add(fs);
					}
			}
		}

		// name new settings
		ctrlWizard.nameNewSettings(listFreqSettings, 'FrequencySetting');

		if (listFStoDel.size() > 0) delete listFStoDel;
		upsert listFreqSettings;
		AddEmptyRows();
		isEditingTab = false;
		ctrlWizard.strCurrentTab = 'tabFrequency';
		return null;
	}
	
	public PageReference cancelTab() {
		isEditingTab = false;
		listFreqSettings = null;
		PageReference p = new PageReference('/apex/ETSettingsWizard?currentTab=tabFrequency');
		p.setRedirect(true);
		return p;
	}

	private boolean isnullStr(string str) {
		return (str == null || str == '');
	}

	private boolean isnullNum(decimal num) {
		return (num == null || num == 0);
	}

	//---------------------------------------- TEST CODE -------------------------------------------------
	static testmethod void TestTabFrequency() {
		GW_CTRL_ETSettingsWizard ctrl = new GW_CTRL_ETSettingsWizard();
		system.assert(ctrl.ctabFrequency != null);
		system.assertEquals(ctrl.ctabFrequency.ctrlWizard, ctrl);
		system.assertEquals(ctrl.ctabFrequency.isEditingTab, false);
		system.assert(ctrl.ctabFrequency.listFreqSettings != null);
		ctrl.ctabFrequency.editTab();
		system.assertEquals(ctrl.strCurrentEditTab, 'tabFrequency');
		ctrl.ctabFrequency.saveTab();
		system.assertEquals(ctrl.strCurrentEditTab, null);
		system.assert(ctrl.ctabFrequency.cancelTab() != null);		
	}
	
}