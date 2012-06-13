global class GW_BATCH_CampaignEngagementRollup implements Database.Batchable<Sobject>, Database.Stateful, Schedulable {


    string batchQuery;
    
    // cursors
    id hierarchyCursor;
    id campCursor;
    id conCursor;
    
    // tallies
    long conTally,leadTally,respTally,respAtLvlTally;
    
    // map of wrapper classes
    map <id,campTotals> wrapMap; 


	// wrapper class
	public class campTotals {
		id campId;
		integer engLvl;
		long conCount,leadCount,respCount;
		
		// constructor
		public campTotals (id campId) {
			this.campId = campId;
			conCount = 0;
			leadCount = 0;
			respCount = 0;
		}
	}


    global GW_BATCH_CampaignEngagementRollup() {
    	// construtor
  		wrapMap = new map <id,campTotals>();
  		constructQuery();  
    }
    
    
    global void execute(SchedulableContext SC) {
    
    }
    
    
    private void constructQuery () {
    	string soql = 'SELECT Id,CampaignId,ContactId,LeadId,Status,HasResponded,';
    	soql +=			' Campaign.Parent.Id,Campaign.Parent.Parent.Id,Campaign.Parent.Parent.Parent.Id,Campaign.Parent.Parent.Parent.Parent.Id, ';
    	soql +=			' Campaign.Parent.Engagement_Level_Numeric__c,Campaign.Parent.Parent.Engagement_Level_Numeric__c,Campaign.Parent.Parent.Parent.Engagement_Level_Numeric__c,Campaign.Parent.Parent.Parent.Parent.Engagement_Level_Numeric__c ';
    	soql +=			' FROM CampaignMember';
    	// soql +=			'WHERE ';
    	soql +=			' ORDER BY Campaign.Top_Hierarchy_Campaign_ID__c,Campaign.Levels_Below_Top_of_Hierarchy__c DESC,CampaignId,ContactId';
    	
    	batchQuery = soql;
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator(batchQuery);
    }


    global void execute(Database.BatchableContext BC, List<Sobject> SBatch){
		
        for (sobject s: SBatch) {
            CampaignMember cm = (CampaignMember)s;
			
			if (cm.CampaignId != campCursor) {
				// new campaign, finalize numbers on old campaign
				
				// first see if we alrady have totals for this campaign (rolled up from subcampaign(s))
				campTotals totals = wrapMap.get(campCursor);
				
				// if not start a fresh one
				if (totals == null) {
					totals = new campTotals (campCursor);
				}
				
				// then add in our tallies
				totals.conCount += conTally;
				totals.leadCount += leadTally;
				totals.respCount += respTally;
				
			}

			if (cm.Campaign.Top_Hierarchy_Campaign_ID__c != hierarchyCursor) {
				// tbd new campaign "group"
			}
			if (cm.ContactId != conCursor) {
				// tbd new contact
			}
			
			if (cm.ContactId != null) {
				conTally += 1;
			} else if (cm.LeadId != null) {
				leadTally += 1;
			}
			if (cm.HasResponded == true) {
				respTally += 1;
			}         	   
        }
		
    }  

    global void finish(Database.BatchableContext BC){
        
    }


	//  TESTS ****************************************************
	
	static testmethod void testCampaignRollup () {
		
        string txtfield1 = 'Title';
        double txtfield1lvl = 6;
        string txtfield1FV = 'Board Member';
		GW_BATCH_EngagementRollup.setSettingsForTests(txtfield1, txtfield1FV, txtfield1lvl);
		
		Campaign top1 = new Campaign (name = 'top1');
		insert top1;
		Campaign sub1a = new Campaign (name = 'sub1a',ParentId = top1.Id,Leadership_Level__c = '3 - lvl three');
		insert sub1a;
		Campaign subsub1aa = new Campaign (name = 'subsub1aa',ParentId = sub1a.Id,Leadership_Level__c = '3 - lvl three');
		insert subsub1aa;
		Campaign subsub1ab = new Campaign (name = 'subsub1ab',ParentId = sub1a.Id,Leadership_Level__c = '1 - lvl one');
		insert subsub1ab;
		
		Id[] allCampIds = new Id[] {top1.Id,sub1a.Id,subsub1aa.Id,subsub1ab.Id};
		
		// create cons
        Contact[] cons = ONEN_UnitTestData.CreateMultipleTestContacts(15);
        insert cons;
        
        // first few cons responded on parent
        set<id> con0thru2 = new set<id> {cons[0].Id,cons[1].Id,cons[2].Id} ;
        insert testCMs(sub1a.Id,con0thru2,'Responded');
		
		// one of those plus 4 new ones responded on child that counts
        set<id> con2thru6 = new set<id> {cons[2].Id,cons[3].Id,cons[4].Id,cons[5].Id,cons[6].Id} ;
        insert testCMs(subsub1aa.Id,con2thru6,'Responded');
		
		// all of those plus 4 new ones responded on chlid that doesn't count
        set<id> con2thru10 = new set<id> {cons[2].Id,cons[3].Id,cons[4].Id,cons[5].Id,cons[6].Id,cons[7].Id,cons[8].Id,cons[9].Id,cons[10].Id} ;
        insert testCMs(subsub1ab.Id,con2thru10,'Responded');

		// and finally 4 more that didn't respond on same campaign
        set<id> con11thru14 = new set<id> {cons[11].Id,cons[12].Id,cons[13].Id,cons[14].Id} ;
        insert testCMs(subsub1ab.Id,con11thru14,'Sent');
        
        // run batch
        Test.StartTest();
        GW_BATCH_CampaignEngagementRollup myba = new GW_BATCH_CampaignEngagementRollup ();
        ID batchprocessid = Database.executeBatch(myba);
        Test.StopTest();
        
        // make sure rollup is correct
        map<id,Campaign> campMap = new map<id,Campaign> ([SELECT Id,Name,ParentId,Total_Unique_Contacts_In_Hierarchy__c,
        					Total_Unique_Responses_in_Hierarchy__c,Response_Rate_for_Hierarchy__c
        					FROM Campaign WHERE Id IN :allCampIds]);
        					
        Campaign top1p = campMap.get(top1.Id);
        system.assertEquals (15,top1p.Total_Unique_Contacts_In_Hierarchy__c);
        system.assertEquals (11,top1p.Total_Unique_Responses_in_Hierarchy__c);
        system.assertEquals (null,top1p.Response_Rate_for_Hierarchy__c);
        					
        Campaign sub1aP = campMap.get(sub1a.Id);
        system.assertEquals (15,sub1aP.Total_Unique_Contacts_In_Hierarchy__c);
        system.assertEquals (11,sub1aP.Total_Unique_Responses_in_Hierarchy__c);
        system.assertEquals (46.7,sub1aP.Response_Rate_for_Hierarchy__c);
        					
        Campaign subsub1aaP = campMap.get(subsub1aa.Id);
        system.assertEquals (5,subsub1aaP.Total_Unique_Contacts_In_Hierarchy__c);
        system.assertEquals (5,subsub1aaP.Total_Unique_Responses_in_Hierarchy__c);
        system.assertEquals (100,subsub1aaP.Response_Rate_for_Hierarchy__c);
        					
        Campaign subsub1abP = campMap.get(subsub1ab.Id);
        system.assertEquals (13,subsub1abP.Total_Unique_Contacts_In_Hierarchy__c);
        system.assertEquals (9,subsub1abP.Total_Unique_Responses_in_Hierarchy__c);
        system.assertEquals (69.2,subsub1abP.Response_Rate_for_Hierarchy__c);
        					
       	
        
		
	}
	
	static list<CampaignMember> testCMs (Id CampId, Set<id> ConIDs, string statusStr) {
		CampaignMember[] cms = new CampaignMember[0]; 
		for (Id conId : ConIDs) {
			CampaignMember cm = new CampaignMember (CampaignId = CampId,ContactId = conId, Status = statusStr);
			cms.add (cm);
		}
		return cms;
 	}


}