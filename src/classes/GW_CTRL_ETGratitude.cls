public with sharing class GW_CTRL_ETGratitude {
	
	// constructor
	public GW_CTRL_ETGratitude() {

		// initialize filter choices
		numRecipients = 10;
		strWhoToInclude = 'Both';
		cmFilter = new CampaignMember();
		
	}
		
	public integer numRecipients { get; set; }
	
	public string strWhoToInclude { get; set; }
	
	// CampaignMember used just to provide a Campaign lookup field on the page
	public CampaignMember cmFilter { get; set; } 
	
	public PageReference GetRecipients() {
		listRecipient = null;
		return null;
	}
	
	// the generated list of Recipients to display
	public list<CRecipient> listRecipient {
		get {
			if (listRecipient == null) {
				listRecipient = new list<CRecipient>();
				set<ID> setConId = new set<ID>();
				integer cCon = 0;

				string strSoql = 'select ContactId ';
				strSoql += ' from CampaignMember ';
				strSoql += ' where Contact.Engagement_Level__c <> null ';
				
				ID cmpId = cmFilter.CampaignId;
				if (cmpId != null) {
					strSoql += ' and CampaignId = :cmpId ';
				}

				if (strWhoToInclude == 'New') {
					strSoql += ' order by Contact.Days_Since_First_Action_at_Level__c asc ';				
				} else if (strWhoToInclude == 'Old') {
					strSoql += ' and Contact.Last_Leadership_Action_Date__c >= LAST_N_DAYS:365 ';
					strSoql += ' order by Contact.Days_Since_First_Action_at_Level__c desc ';				
				}

				list<CampaignMember> listCM = database.query(strSoql);
				for (CampaignMember cm : listCM) {
					if (setConId.add(cm.ContactId)) {
						cCon++;
						if (cCon == numRecipients) {
							break;
						}
					}
				}
				
				strSoql = 'select ' + strContactFields + ' from Contact where Id in :setConId ';
				strSoql += ' ORDER BY Days_Since_First_Action_at_Level__c, LastName, FirstName ';
			
				list<Contact> listCon = database.query(strSoql);
				for (Contact con : listCon) {
					CampaignMember cm = new CampaignMember(contactId=con.Id);
					CRecipient recipient = new CRecipient(con, cm);
					listRecipient.add(recipient);
				}				
			}
			return listRecipient;
		}
		set;
	}
	
	
	public class CRecipient {
		
		public CRecipient(Contact conT, CampaignMember cmT) {
			con = conT;
			cm = cmT;
		}
		
		public Contact con { get; set; }
		public CampaignMember cm { get; set; }
		
	}

	// helper routine to return all Contact field names from the Field Set
	// (which we can now get with Apex, but I'll do it later!)
	private string strContactFields {
		get {
			if (strContactFields == null) {
				
				// initialize the list of all fields on Opportunity.
				// ideally, we'd only include the fields in the Field Set,
				// but Apex currently has no way to see what those are.
				// so for now, we just include all fields on Opportunity.
				Map<String, Schema.SObjectField> mapS = Schema.SObjectType.Contact.fields.getMap();
				list<string> listStrFields = new list<string>();
				listStrFields.addAll(mapS.keySet());  
				strContactFields = '';
				for (string str : listStrFields) {
					strContactFields += 'Contact.' + str + ',';
				}  		
				strContactFields = strContactFields.substring(0, strContactFields.length()-1);
			}
			return strContactFields;
		}
		set;
	}


}