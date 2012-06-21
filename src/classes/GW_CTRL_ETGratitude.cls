public with sharing class GW_CTRL_ETGratitude {
	
	// constructor
	public GW_CTRL_ETGratitude() {

		// initialize filter choices
		numRecipients = 10;
		strWhoToInclude = 'New';
		cmFilter = new CampaignMember();
		
		// start with empty list so it won't get filled.
		listRecipient = new list<CRecipient>();
		
	}
		
	public integer numRecipients { get; set; }
	
	public string strWhoToInclude { get; set; }
	
	// CampaignMember used just to provide a Campaign lookup field on the page
	public CampaignMember cmFilter { get; set; } 
	
	// action method to create a new gratitude campaign
	public PageReference NewGratitudeRun() {
		// create the new campaign
		Campaign cmp = new Campaign();
		cmp.Name = system.now().format('MMMM yyyy') + ' Gratitude Machine';
		cmp.Gratitude_Machine__c = true;
		cmp.StartDate = system.today();
		cmp.IsActive = true;
		cmp.Type = 'Gratitude Machine - ' + (strWhoToInclude == 'New' ? 'New Climbers' : 'Old Steadies');
		cmp.Status = 'In Progress';
		insert cmp;
		
		cmpIdGratitude = cmp.Id;
		listRecipient = null;
		// force it to get filled in action method, so inserting the
		// CampaignMembers will succeed (which fail when accessed from visualforce)
		list<CRecipient> listT = listRecipient;
		return null;
	}
	
	public boolean hasRecipients {
		get {
			return listRecipient != null && listRecipient.size() > 0;
		}
	}
	
	// the generated list of Recipients to display
	//
	// strategies:
	//
	// - if we aren't filtering by Campaign, just query directly against Contact (DONE)
	//
	// - if filtering by Campaign, need to get id's of Campaign and its ancestors,
	// 		and query against campaign members who are in that set of campaigns.  (DONE)
	//
	// - for New Climbers, look at smallest 'days in current level', and make sure they went up a level, not down. (DONE)
	//
	// - for Old Steadies, look for largest 'days in current level' with some action in the last N days. (DONE)
	//
	// - only include people who are at least level X. (DONE)
	private static integer minLevel = 2;
	//
	// - only include people once! (DONE)
	//
	// - only include a single person from a household.  
	//		(seems lower priority; let them see both and they can choose who to talk to)
	//
	// - exclude people who have already been 'loved' in the last N days.
	//		need to decide how this is tracked:
	//		- look at campaign members of type Gratitude Machine with appropriate status
	//		- look at activities of unique record type or custom field value
	//		- look at custom field on contact (last loved date)
	// 
	public list<CRecipient> listRecipient {
		get {
			if (listRecipient == null) {
				listRecipient = new list<CRecipient>();
				set<ID> setConId = new set<ID>();
				integer cCon = 0;
				string strSoql;
				
				// if we are filtering by campaigns....
				if (cmFilter.CampaignId != null) {

					strSoql = 'select ContactId ';
					strSoql += ' from CampaignMember ';
					strSoql += ' where Contact.Engagement_Level__c <> null and Contact.Engagement_Level_Numeric__c >= :minLevel';
					
					set<ID> setCmpId;
					setCmpId = setCampaignsToFilter();
					strSoql += ' and CampaignId in :setCmpId ';
	
					if (strWhoToInclude == 'New') {
						strSoql += ' and Contact.Last_Engagement_Change__c >= 0 ';
						strSoql += ' order by Contact.Days_Since_First_Action_at_Level__c asc ';				
					} else if (strWhoToInclude == 'Old') {
						strSoql += ' and Contact.Last_Leadership_Action_Date__c >= LAST_N_DAYS:365 ';
						strSoql += ' order by Contact.Days_Since_First_Action_at_Level__c desc ';				
					}
					strSoql += ' limit 100 ';
	
					// get the list of CampaignMembers, and extract numRecipients (since multi campaign, contacts can be duped)
					list<CampaignMember> listCM = database.query(strSoql);
					for (CampaignMember cm : listCM) {
						if (setConId.add(cm.ContactId)) {
							cCon++;
							if (cCon >= numRecipients) {
								break;
							}
						}
					}  
 
					strSoql = 'select ' + strContactFields + ' from Contact ';
					strSoql += ' where Id in :setConId ';	
					strSoql += ' order by Days_Since_First_Action_at_Level__c, LastName, FirstName ';

				} else { // we are NOT filtering by Campaigns...				
					strSoql = 'select ' + strContactFields + ' from Contact ';
					strSoql += ' where Contact.Engagement_Level__c <> null and Contact.Engagement_Level_Numeric__c >= :minLevel';

					if (strWhoToInclude == 'New') {
						strSoql += ' and Contact.Last_Engagement_Change__c >= 0 ';
						strSoql += ' order by Contact.Days_Since_First_Action_at_Level__c asc, LastName asc, FirstName  asc ';				
					} else if (strWhoToInclude == 'Old') {
						strSoql += ' and Contact.Last_Leadership_Action_Date__c >= LAST_N_DAYS:365 ';
						strSoql += ' order by Contact.Days_Since_First_Action_at_Level__c desc, LastName asc, FirstName asc ';				
					}
					strSoql += ' limit ' + string.valueOf(numRecipients);				
				}				

				// we now have a soql string on contacts.  do it and create our recipient list.
				list<Contact> listCon = database.query(strSoql);
				list<CampaignMember> listCMNew = new list<CampaignMember>();
				for (Contact con : listCon) {
					CampaignMember cm = new CampaignMember(contactId=con.Id, campaignId=cmpIdGratitude, Status='Sent');
					listCMNew.add(cm);
					CRecipient recipient = new CRecipient(con, cm);
					listRecipient.add(recipient);
				} 
				system.debug('DJH about to insert listCMNew');
				system.debug(listCMNew);  
				insert listCMNew;
			} 
			return listRecipient;
		}
		set;
	}
	
	// utility to return the set of all campaignId's that are descendents of the filter campaignId.
	private set<ID> setCampaignsToFilter() {
		if (cmFilter.CampaignId == null) 
			return null;

		set<ID> setCmpId = new set<ID>();
		setCmpId.add(cmFilter.CampaignId);

		set<ID> setCmpIdParent = new set<ID>();
		setCmpIdParent.add(cmFilter.CampaignId);
		
		while (true) {
			list<Campaign> listCmp = [select Id from Campaign where ParentId in :setCmpIdParent];
			if (listCmp.size() == 0)
				break;
			setCmpIdParent.clear();
			for (Campaign cmp : listCmp) {
				setCmpId.add(cmp.Id);
				setCmpIdParent.add(cmp.Id);
			}
		}
		
		return setCmpId;		
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

	// action method to start over
	public PageReference doneWithRecipients() {
		// reset with empty list so it won't get filled.
		listRecipient = new list<CRecipient>();	
		// force list of gratitude campaigns to get refreshed (since we just edited one!)
		listCmpGratitude = null;	
		return null;
	}
	
	// the Gratitude campaign currently being edited
	public ID cmpIdGratitude { get; set; }
	
	// list of recent Gratitude campaigns
	public list<Campaign> listCmpGratitude {
		get {
			if (listCmpGratitude == null) {
				listCmpGratitude = [select Id, Name, Type, NumberOfContacts, NumberOfResponses, StartDate 
					from Campaign
					where Gratitude_Machine__c = true limit 10];
			}
			return listCmpGratitude;			
		}
		set;
	}

}