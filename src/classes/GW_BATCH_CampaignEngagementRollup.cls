global class GW_BATCH_CampaignEngagementRollup implements Database.Batchable<Sobject>, Database.Stateful, Schedulable {


    string batchQuery;
    
    // cursors
    id hierarchyCursor;
    id campCursor;
    id conCursor;
    
    /* 
    // tallies
    long conTally,leadTally,respTally,respAtLvlTally;
    */
    
    // map of wrapper classes
    map <id,campTotals> wrapMap; 


	// wrapper class
	public class campTotals {
		id campId;
		Campaign camp;
		integer engLvl;
		long conCount,leadCount,respCount,engRespCount;		// overall totals
		boolean currConSent,currConSentLead,currConResp,currConEngResp;		// temporary flags for each contact in loop
		
		set<Id> parentCampIDs;						// all direct parents
		set<Id> eligibleParentCampIDs;				// only those parents that our responses will roll up to for response rate 
													// i.e. has eng. level, but is same or lower than my level 
		
		// constructor
		public campTotals (Campaign camp) {
			this.campId = camp.Id;
			this.camp = camp;
			this.engLvl = (camp.Engagement_Level_Numeric__c == null) ? null : camp.Engagement_Level_Numeric__c.intvalue();
			
			this.conCount = 0;
			this.leadCount = 0;
			this.respCount = 0;
			this.parentCampIDs = new set<Id>();
			this.eligibleParentCampIDs = new set<Id>();
			
			if (camp.Parent.Id != null) parentCampIDs.add(camp.Parent.Id);
			if (camp.Parent.Engagement_Level_Numeric__c <= engLvl) eligibleParentCampIDs.add(camp.Parent.Parent.Id);
			if (camp.Parent.Parent.Id != null) parentCampIDs.add(camp.Parent.Parent.Id);
			if (camp.Parent.Parent.Engagement_Level_Numeric__c <= engLvl) eligibleParentCampIDs.add(camp.Parent.Parent.Id);
			if (camp.Parent.Parent.Parent.Id != null) parentCampIDs.add(camp.Parent.Parent.Parent.Id);
			if (camp.Parent.Parent.Parent.Engagement_Level_Numeric__c <= engLvl) eligibleParentCampIDs.add(camp.Parent.Parent.Parent.Id);
			if (camp.Parent.Parent.Parent.Parent.Id != null) parentCampIDs.add(camp.Parent.Parent.Parent.Parent.Id);
			if (camp.Parent.Parent.Parent.Parent.Engagement_Level_Numeric__c <= engLvl) eligibleParentCampIDs.add(camp.Parent.Parent.Parent.Parent.Id);
		}
		
		public void SetCurrConFlags (boolean isLead, boolean isResp, integer respLvl) {
			// based on a campaign membership being considered by the main process, set boolean flags 
			// which indicate whether we have a send/response/etc for the current contact
			// in every case we don't need to check what the current value of flag is, setting it to true twice doesn't hurt anything
			if (isLead) {
				currConSentLead = true;
			} else {
				currConSent = true;
			}
			if (isResp) currConResp = true;
			if (respLvl >= engLvl) currConEngResp = true;
		}
		
		public void SetCurrConFlagsParents (boolean isLead, boolean isResp, integer respLvl) {
			// set the flags (as in the SetCurrConFlags method) but for all appropriate parents of this campaign
			for (Id parentCampId : parentCampIDs) {
				
			}
		}
		
		public void ResetCurrConFlags () {
			currConSentLead = false;
			currConSent = false;
			currConResp = false;
			currConEngResp = false;
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
    	string soql = 'SELECT Id,CampaignId,ContactId,LeadId,Status,HasResponded,Campaign.Engagement_Level_Numeric__c,';
    	soql +=			' Campaign.Parent.Id,Campaign.Parent.Parent.Id,Campaign.Parent.Parent.Parent.Id,Campaign.Parent.Parent.Parent.Parent.Id, ';
    	soql +=	 		' Campaign.Parent.Engagement_Level_Numeric__c,Campaign.Parent.Parent.Engagement_Level_Numeric__c,Campaign.Parent.Parent.Parent.Engagement_Level_Numeric__c,Campaign.Parent.Parent.Parent.Parent.Engagement_Level_Numeric__c, ';
    	soql +=	 		' Campaign.Top_Hierarchy_Campaign_ID__c ';
    	soql +=			' FROM CampaignMember';
    	// soql +=			'WHERE ';
    	soql +=			' ORDER BY Campaign.Top_Hierarchy_Campaign_ID__c,ContactId,LeadId,Campaign.Levels_Below_Top_of_Hierarchy__c DESC,CampaignId';
    	soql = GW_BATCH_EngagementRollup.addAllNSPrefixET(soql,true,false);
    	
    	system.debug (LoggingLevel.WARN,'soql: ' + soql);
    	batchQuery = soql;
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator(batchQuery);
    }


    global void execute(Database.BatchableContext BC, List<Sobject> SBatch){
		
        for (sobject s: SBatch) {
            CampaignMember cm = (CampaignMember)s;
			system.debug (LoggingLevel.WARN,'cm in loop: ' + cm);
			system.debug (LoggingLevel.WARN,'cm.campaign in loop: ' + cm.Campaign);
			
			if (cm.ContactId != conCursor && cm.LeadId != conCursor) {
				// loop thru all campaigns in current hiearchy "group"
				// and add to totals based on booleans
				// tbd
				
				// finally reset the cursor
				conCursor = (cm.ContactId == null) ? cm.LeadId : cm.ContactId;
			}

			if (cm.CampaignId != campCursor) {
				// ***NEW CAMPAIGN***
				// create wrappers (if necessary) for campaign and parents
				CheckForWrappers(cm);
				
				// then reset the cursor
				campCursor = cm.CampaignId;
			}

			if (cm.Campaign.Top_Hierarchy_Campaign_ID__c != hierarchyCursor) {
				// tbd new campaign "group"
			}

			// then always flag which metrics this CM will increment (writes to wrapper for current campaign and all eligible parents)
			// first figure out which metrics this qualifies for
			boolean isResp = false;
			boolean isLead = false;
			integer respLvl = 0;
			if (cm.LeadId != null) {
				isLead = true;
				// conTally += 1;
			}
			if (cm.HasResponded == true) {
				isResp = true;
				// respTally += 1;
			}
			if (cm.Campaign.Engagement_Level_Numeric__c != null) {
				respLvl = cm.Campaign.Engagement_Level_Numeric__c.intvalue();
			}
			campTotals totals = wrapMap.get(cm.Campaign.Id);
			totals.SetCurrConFlags(isLead, isResp, respLvl);
			         	   
        }
		
    }  


	private void CheckForWrappers (CampaignMember cm) {
		// see if we alrady have a wrapper for this campaign (created from subcampaign)
		// if not start a fresh one
		if (wrapMap.get(cm.Campaign.Id) == null) {
			campTotals totals = new campTotals (cm.Campaign);
			wrapMap.put(cm.Campaign.Id,totals);
			system.debug (LoggingLevel.WARN,'new wrap obj: ' + totals);
		}
		
		// then do the same for each of the parents up the chain
		if (cm.Campaign.Parent.Id != null && wrapMap.get(cm.Campaign.Parent.Id) == null) {
			campTotals totals = new campTotals (cm.Campaign.Parent);
			wrapMap.put(cm.Campaign.Parent.Id,totals);					
		}
		if (cm.Campaign.Parent.Parent.Id != null && wrapMap.get(cm.Campaign.Parent.Parent.Id) == null) {
			campTotals totals = new campTotals (cm.Campaign.Parent.Parent);
			wrapMap.put(cm.Campaign.Parent.Parent.Id,totals);					
		}
		if (cm.Campaign.Parent.Parent.Parent.Id != null && wrapMap.get(cm.Campaign.Parent.Parent.Parent.Id) == null) {
			campTotals totals = new campTotals (cm.Campaign.Parent.Parent.Parent);
			wrapMap.put(cm.Campaign.Parent.Parent.Parent.Id,totals);					
		}
		if (cm.Campaign.Parent.Parent.Parent.Parent.Id != null && wrapMap.get(cm.Campaign.Parent.Parent.Parent.Parent.Id) == null) {
			campTotals totals = new campTotals (cm.Campaign.Parent.Parent.Parent.Parent);
			wrapMap.put(cm.Campaign.Parent.Parent.Parent.Parent.Id,totals);					
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