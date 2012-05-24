public with sharing class GW_CTRL_ETSettingsTabContact {
	
	// constructor
	public GW_CTRL_ETSettingsTabContact(GW_CTRL_ETSettingsWizard cWiz) {
		ctrlWizard = cWiz;
		isEditingTab = false;
	}

	private GW_CTRL_ETSettingsWizard ctrlWizard { get; set; }
	
	public list<EngagementContactFieldSettings__c> listFieldSettings {
		get {
			if (listFieldSettings == null) { 
				listFieldSettings = EngagementContactFieldSettings__c.getAll().values();
				AddEmptyRows();
			}
			return listFieldSettings;
		}
		set;
	} 
	
	public PageReference AddEmptyRows() {
		for (integer i = 0; i < 5; i++) {
			listFieldSettings.add(new EngagementContactFieldSettings__c());
		}
		return null;
	}	
	
	public boolean isEditingTab { get; set; }
	
	public PageReference editTab() {
		isEditingTab = true;
		ctrlWizard.strCurrentTab = 'tabContact';
		return null;
	}
	
	public PageReference saveTab() {
		list<EngagementContactFieldSettings__c> listFStoDel = new list<EngagementContactFieldSettings__c>();
		  
		// go thru the field settings and delete empty ones
		// also set the appropriate field type
		for (integer i = listFieldSettings.size()-1; i >= 0; i--) {
			EngagementContactFieldSettings__c fs = listFieldSettings[i];

			if (ctrlWizard.setCheckboxFields.contains(fs.Fieldname__c)) {
				listFieldSettings[i].Field_Type__c = 'checkbox';
			} else {
				listFieldSettings[i].Field_Type__c = 'text';
			}				

			if (ctrlWizard.isnullStr(fs.Fieldname__c) &&
				ctrlWizard.isnullStr(fs.Field_Value__c) &&
				ctrlWizard.isnullNum(fs.Level_Value__c)) {
				
					if (fs.Id == null) {
						// it's a new empty fs; just remove it
						listFieldSettings.remove(i);
					} else {
						// it's an existing, but cleared entry; delete it.
						listFieldSettings.remove(i);
						listFStoDel.add(fs);
					}
			}
		}

		// name new settings
		ctrlWizard.nameNewSettings(listFieldSettings, 'FieldSetting');
				
		if (listFStoDel.size() > 0) delete listFStoDel;
        try {
			upsert listFieldSettings;
        } catch (exception ex) {
        	ApexPages.addMessages(ex);
        	return null;
        }		
		AddEmptyRows();
		isEditingTab = false;
		ctrlWizard.strCurrentTab = 'tabContact';
		return null;
	}
	
	public PageReference cancelTab() {
		isEditingTab = false;
		listFieldSettings = null;
		PageReference p = new PageReference('/apex/ETSettingsWizard?currentTab=tabContact');
		p.setRedirect(true);
		return p;
	}

	//---------------------------------------- TEST CODE -------------------------------------------------
	static testmethod void TestTabContact() {
		GW_CTRL_ETSettingsWizard ctrl = new GW_CTRL_ETSettingsWizard();
		system.assert(ctrl.ctabContact != null);
		system.assertEquals(ctrl.ctabContact.ctrlWizard, ctrl);
		system.assertEquals(ctrl.ctabContact.isEditingTab, false);
		system.assert(ctrl.ctabContact.listFieldSettings != null);
		system.assert(ctrl.listSOContactFields != null);	// to force setCheckboxFields to get created.
		ctrl.ctabContact.editTab();
		system.assertEquals(ctrl.strCurrentEditTab, 'tabContact');
		ctrl.ctabContact.saveTab();
		system.assertEquals(ctrl.strCurrentEditTab, null);
		system.assert(ctrl.ctabContact.cancelTab() != null);		
	}


}