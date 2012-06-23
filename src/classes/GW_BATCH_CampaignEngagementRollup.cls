global class GW_BATCH_CampaignEngagementRollup implements Database.Batchable<Sobject>, Database.Stateful, Schedulable {


    string batchQuery;
    
    // cursors
    id hierarchyCursor;
    id campCursor;
    id conCursor;
    
    // map of wrapper classes
    map <id,campTotals> wrapMap; 

	// list of campaign writes 
	Campaign[] campsToUpdate;


	// WRAPPER CLASS
	public class campTotals {
		public id campId;
		public Campaign camp;
		public integer engLvl;
		public long conCount,leadCount,respCount,engRespCount,convCandidateCount,convCount;		// overall totals
		boolean currConSent,currConSentLead,currConResp,currConEngResp,currConConvCandidate,currConConv;		// temporary flags for each contact in loop
		decimal responseRate,conversionRate;
		string campName;
		
		set<Id> parentCampIDs;						// all direct parents
		set<Id> eligibleParentCampIDs;				// only those parents that our responses will roll up to for response rate 
													// i.e. has eng. level, but is same or lower than my level 
		
		// constructor
		public campTotals (Campaign camp) {
			this.campId = camp.Id;
			this.camp = camp;
			this.engLvl = (camp.Engagement_Level_Numeric__c == null) ? null : camp.Engagement_Level_Numeric__c.intvalue();
			this.campName = camp.Name;
			
			this.conCount = 0;
			this.leadCount = 0;
			this.respCount = 0;
			this.engRespCount = 0;
			this.convCandidateCount = 0;
			this.convCount = 0;
			this.parentCampIDs = new set<Id>();
			this.eligibleParentCampIDs = new set<Id>();
			
			ResetCurrConFlags();
			
			if (camp.Parent.Id != null) parentCampIDs.add(camp.Parent.Id);
			if (camp.Parent.Engagement_Level_Numeric__c <= engLvl) eligibleParentCampIDs.add(camp.Parent.Parent.Id);
			if (camp.Parent.Parent.Id != null) parentCampIDs.add(camp.Parent.Parent.Id);
			if (camp.Parent.Parent.Engagement_Level_Numeric__c <= engLvl) eligibleParentCampIDs.add(camp.Parent.Parent.Id);
			if (camp.Parent.Parent.Parent.Id != null) parentCampIDs.add(camp.Parent.Parent.Parent.Id);
			if (camp.Parent.Parent.Parent.Engagement_Level_Numeric__c <= engLvl) eligibleParentCampIDs.add(camp.Parent.Parent.Parent.Id);
			if (camp.Parent.Parent.Parent.Parent.Id != null) parentCampIDs.add(camp.Parent.Parent.Parent.Parent.Id);
			if (camp.Parent.Parent.Parent.Parent.Engagement_Level_Numeric__c <= engLvl) eligibleParentCampIDs.add(camp.Parent.Parent.Parent.Parent.Id);
			
			system.debug (LoggingLevel.WARN,'new wrap obj: ' + this);
		}
		
		public void SetCurrConFlags (boolean isLead, boolean isResp, integer respLvl, boolean isConvCandidate, boolean isConv) {
			// based on a campaign membership being considered by the main process, set boolean flags 
			// which indicate whether we have a send/response/etc for the current contact
			// in every case we don't need to check what the current value of flag is, setting it to true twice doesn't hurt anything
			if (isLead) {
				currConSentLead = true;
			} else {
				currConSent = true;
			}
			if (isResp) currConResp = true;
			if (isResp && respLvl >= engLvl) currConEngResp = true;
			currConConvCandidate = isConvCandidate;
			if (isConv && respLvl >= engLvl) currConConv = true;
			system.debug (LoggingLevel.WARN,'set curr con flags for campaign ' + camp.Name + ':  ' + 'currConSent=' + currConSent + '  currConResp=' + currConResp + '  currConEngResp=' + currConEngResp);
		}
		
		public void SetCurrConFlagsParents (boolean isLead, boolean isResp, integer respLvl, boolean isConvCandidate, boolean isConv , map <id,campTotals> wrapMap) {
			// set the flags (as in the SetCurrConFlags method) but for all appropriate parents of this campaign
			for (Id parentCampId : parentCampIDs) {
				campTotals parentTotals = wrapMap.get(parentCampId);
				if (isLead) {
					parentTotals.currConSentLead = true;
				} else {
					parentTotals.currConSent = true;
				}
				if (isResp) parentTotals.currConResp = true;
				if (isResp && respLvl >= parentTotals.engLvl) parentTotals.currConEngResp = true;
				ParentTotals.currConConvCandidate = isConvCandidate;
				if (isConv && respLvl >= parentTotals.engLvl) parentTotals.currConConv = true;
				system.debug (LoggingLevel.WARN,'set curr con flags for campaign ' + ParentTotals.camp.Name + ':  ' + 'currConSent=' + ParentTotals.currConSent + '  currConResp=' + ParentTotals.currConResp + '  currConEngResp=' + ParentTotals.currConEngResp);
			}
		}
		
		private void ResetCurrConFlags () {
			currConSentLead = false;
			currConSent = false;
			currConResp = false;
			currConEngResp = false;
			currConConvCandidate = false;
			currConConv = false;
		}
		
		public void UpdateTotals () {
			// increment totals based on whether con flags are set, then clear the flags
			if (currConSent) conCount += 1;
			if (currConSentLead) leadCount += 1;
			if (currConResp) respCount += 1;
			if (currConEngResp) engRespCount += 1;
			if (currConConvCandidate) convCandidateCount += 1;
			if (currConConv) convCount += 1;
			ResetCurrConFlags();
			system.debug (LoggingLevel.WARN,'wrapper after updating totals: ' + this);
		}
		
		private void calculateResponseRate () {
			long totalCount = conCount + leadCount;
			if (engLvl > 0 && totalCount > 0) {
				// need to convert integers to decimals otherwise division doesn't work
				responseRate = (decimal.valueOf(engRespCount) / decimal.valueOf(totalCount) ) * 100;
				responseRate = responseRate.setScale (1,System.RoundingMode.HALF_UP);				// round to one decimal place
			} else {
				system.debug (LoggingLevel.WARN,'skipped calcing response rate for campaign ' + camp.Name);
			}
			system.debug (LoggingLevel.WARN,'calculated response rate for campaign ' + camp.Name + ': totalCount=' + totalCount + '  engRespCount=' + engRespCount + '  responserate=' + responseRate);
		}
		
		private void calculateConversionRate() {
			if (engLvl > 0 && convCandidateCount > 0) {
				// need to convert integers to decimals otherwise division doesn't work
				conversionRate = (decimal.valueOf(convCount) / decimal.valueOf(convCandidateCount) ) * 100;
				conversionRate = conversionRate.setScale (1,System.RoundingMode.HALF_UP);				// round to one decimal place
			} else {
				system.debug (LoggingLevel.WARN,'skipped calcing conversion rate for campaign ' + camp.Name);
			}
			system.debug (LoggingLevel.WARN,'calculated conversion rate for campaign ' + camp.Name + ': candidates=' + convCandidateCount + '  conversions=' + convCount + '  convrate=' + conversionRate);
		}
		
		public Campaign getCampaignForUpdate () {
			// returns a campaign obj ready for writing if any values have changed
			// otherwise returns null
			
			// first calculate the actual response rate & conversion rate
			calculateResponseRate();
			calculateConversionRate();
			
			// TBD ADD LEADS
			if ( conCount != camp.Total_Unique_Contacts_In_Hierarchy__c || respCount != camp.Total_Unique_Responses_in_Hierarchy__c 
				|| responseRate != camp.Engagement_Response_Rate__c || conversionRate != camp.Engagement_Conversion_Rate__c) {
				Campaign campForUpdate = new Campaign (
					Id = camp.Id,
					Total_Unique_Contacts_In_Hierarchy__c = conCount,
					Total_Unique_Responses_in_Hierarchy__c = respCount,
					Total_Unique_Leads_in_Hierarchy__c = leadCount,
					Engagement_Response_Rate__c = responseRate,
					Engagement_Conversion_Rate__c = conversionRate
				);
				system.debug (LoggingLevel.WARN,'returning campaign for write: ' + campForUpdate);
				return campForUpdate;
			} else {
				system.debug (LoggingLevel.WARN,'no write needed for: ' + camp);
				return null;
			}
		} 
		
	}


    global GW_BATCH_CampaignEngagementRollup() {
    	// construtor
  		wrapMap = new map <id,campTotals>();
  		campsToUpdate = new Campaign[0];
  		constructQuery();  
    }
    
    
    global void execute(SchedulableContext SC) {
    	// tbd get batch size from settings?
        GW_BATCH_CampaignEngagementRollup myBatch = new GW_BATCH_CampaignEngagementRollup();
        id batchinstanceid = database.executeBatch (myBatch, 50);      
    }
    
    
    private void constructQuery () {
    	string soql = 'SELECT Id,CampaignId,ContactId,LeadId,Status,HasResponded,Campaign.Id,Campaign.Name,Campaign.Engagement_Level_Numeric__c,Contact.Name, ';
    	soql +=			' Conversion_Candidate__c,Engagement_Conversion__c,Campaign.Total_Unique_Leads_in_Hierarchy__c, ';
    	soql +=			' Campaign.Total_Unique_Contacts_In_Hierarchy__c,Campaign.Total_Unique_Responses_in_Hierarchy__c,Campaign.Engagement_Response_Rate__c,Campaign.Engagement_Conversion_Rate__c, ';
    	soql +=			' Campaign.Parent.Total_Unique_Contacts_In_Hierarchy__c,Campaign.Parent.Total_Unique_Responses_in_Hierarchy__c,Campaign.Parent.Engagement_Response_Rate__c,Campaign.Parent.Engagement_Conversion_Rate__c, ';
    	soql +=			' Campaign.Parent.Parent.Total_Unique_Contacts_In_Hierarchy__c,Campaign.Parent.Parent.Total_Unique_Responses_in_Hierarchy__c,Campaign.Parent.Parent.Engagement_Response_Rate__c,Campaign.Parent.Parent.Engagement_Conversion_Rate__c, ';
    	soql +=			' Campaign.Parent.Parent.Parent.Total_Unique_Contacts_In_Hierarchy__c,Campaign.Parent.Parent.Parent.Total_Unique_Responses_in_Hierarchy__c,Campaign.Parent.Parent.Parent.Engagement_Response_Rate__c,Campaign.Parent.Parent.Parent.Engagement_Conversion_Rate__c, ';
    	soql +=			' Campaign.Parent.Parent.Parent.Parent.Total_Unique_Contacts_In_Hierarchy__c,Campaign.Parent.Parent.Parent.Parent.Total_Unique_Responses_in_Hierarchy__c,Campaign.Parent.Parent.Parent.Parent.Engagement_Response_Rate__c,Campaign.Parent.Parent.Parent.Parent.Engagement_Conversion_Rate__c, ';
    	soql +=			' Campaign.Parent.Id,Campaign.Parent.Parent.Id,Campaign.Parent.Parent.Parent.Id,Campaign.Parent.Parent.Parent.Parent.Id, ';
    	soql +=			' Campaign.Parent.Name,Campaign.Parent.Parent.Name,Campaign.Parent.Parent.Parent.Name,Campaign.Parent.Parent.Parent.Parent.Name, ';
    	soql +=	 		' Campaign.Parent.Engagement_Level_Numeric__c,Campaign.Parent.Parent.Engagement_Level_Numeric__c,Campaign.Parent.Parent.Parent.Engagement_Level_Numeric__c,Campaign.Parent.Parent.Parent.Parent.Engagement_Level_Numeric__c, ';
    	soql +=	 		' Campaign.Top_Hierarchy_Campaign_ID__c, ';
    	soql +=	 		' Campaign.Parent.Total_Unique_Leads_in_Hierarchy__c,Campaign.Parent.Parent.Total_Unique_Leads_in_Hierarchy__c,Campaign.Parent.Parent.Parent.Total_Unique_Leads_in_Hierarchy__c,Campaign.Parent.Parent.Parent.Parent.Total_Unique_Leads_in_Hierarchy__c ';
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
			
			if ((cm.ContactId != conCursor && cm.LeadId != conCursor) || cm.Campaign.Top_Hierarchy_Campaign_ID__c != hierarchyCursor) {
				// loop thru all campaigns in current hiearchy "group"
				// and add to totals based on booleans
				// we also do this when campaign hierarchy cursor turns over b/c although unlikely, it's possible we could end one group
				// and start the next w/ the same contact
				system.debug (LoggingLevel.WARN,'starting new contact: ' + cm.Contact.Name);
								
				// but don't do it for the very first one!
				if (conCursor != null) { 
					updateCampaignTotals();
				}
				
				// and then reset the cursor
				conCursor = (cm.ContactId == null) ? cm.LeadId : cm.ContactId;
			}

			if (cm.Campaign.Top_Hierarchy_Campaign_ID__c != hierarchyCursor) {
				// new campaign "group"
				system.debug (LoggingLevel.WARN,'starting new hierarchy!');

				// after the very first one..
				if (hierarchyCursor != null) {
					// collect our writes
					getCampaignWrites();
					// garbage collect - clear out our map so we don't retain it and make it huge during a big batch run
					wrapMap.clear();
				}
				
				// then reset the cursor
				hierarchyCursor = cm.Campaign.Top_Hierarchy_Campaign_ID__c;			
			}

			if (cm.CampaignId != campCursor) {
				// ***NEW CAMPAIGN***
				system.debug (LoggingLevel.WARN,'starting new campaign: ' + cm.Campaign.Name);

				// create wrappers (if necessary) for campaign and parents
				CheckForWrappers(cm);
				
				// then reset the cursor
				campCursor = cm.CampaignId;
			}


			// then always flag which metrics this CM will increment (writes to wrapper for current campaign and all eligible parents)
			// first figure out which metrics this qualifies for
			boolean isResp = false;
			boolean isLead = false;
			boolean isConvCandidate = false;
			integer respLvl = 0;
			if (cm.LeadId != null) isLead = true;
			if (cm.HasResponded == true) isResp = true;
			if (cm.Campaign.Engagement_Level_Numeric__c != null) respLvl = cm.Campaign.Engagement_Level_Numeric__c.intvalue();
			if (cm.Conversion_Candidate__c == 'True') isConvCandidate = true;
			boolean isConv = cm.Engagement_Conversion__c;
			campTotals totals = wrapMap.get(cm.Campaign.Id);
			// system.debug (LoggingLevel.WARN,'wrapper before setting currCon flags: ' + totals);		
			// system.debug (LoggingLevel.WARN,'campaignID for cm: ' + cm.Campaign.Id);		
			totals.SetCurrConFlags(isLead, isResp, respLvl, isConvCandidate, isConv);
			totals.SetCurrConFlagsParents(isLead, isResp, respLvl, isConvCandidate, isConv, wrapMap);
			         	   
        }
        
        // after the loop is done, do any writes we've collected during this batch
        // which will only happen if we completed that campaign hierarchy during this batch
		doCampaignWrites();		
    }  


    global void finish(Database.BatchableContext BC){
		// after last batch..
		
		// try updating one more time, to make sure we got the very last contact
		updateCampaignTotals();
		
		// then get our last writes, and do them
		getCampaignWrites();
		doCampaignWrites();
    }
    
    
    	
	private void getCampaignWrites () {
		// collect any campaign writes and add to list
		// we'll actually do the update at the end of each batch
		// b/c if the batch spans multiple hierarchies, we don't want to do a bunch of separate writes
		system.debug (LoggingLevel.WARN,'hierarchy cursor changed, getting campaign writes');	
		for (campTotals totals : wrapMap.values()) {
			Campaign camp = totals.getCampaignForUpdate();
			if (camp != null) campsToUpdate.add (camp);
		}
	}


	private void doCampaignWrites () {
        system.debug (LoggingLevel.WARN,'campaigns for update at end of batch: ' + campsToUpdate);
        if (campsToUpdate != null) {
        	update campsToUpdate;
        	campsToUpdate.clear();
        }
	}
	
	
	private void updateCampaignTotals () {
		// loop thru all campaigns in current hiearchy "group"
		// and add to totals based on booleans, meanwhile resetting the flags for the current contact	
		for (campTotals totals : wrapMap.values()) {
			totals.UpdateTotals();
		}	
	}

	private void CheckForWrappers (CampaignMember cm) {
		// see if we alrady have a wrapper for this campaign (created from subcampaign)
		// if not start a fresh one
		campTotals thisTotals = wrapMap.get(cm.Campaign.Id);
		if (thisTotals == null) {
			campTotals totals = new campTotals (cm.Campaign);
			wrapMap.put(cm.Campaign.Id,totals);
/*			
		} else {
			// even if we do have a wrapper already, update it with the full campaign data (which we only query for for each campaign, not parents)
			thisTotals.camp = cm.Campaign;
*/ 
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
		
		// system.debug (LoggingLevel.WARN,'wrapMap after additions: ' + wrapMap);		
	}





	//  TESTS ****************************************************
	
	static testmethod void testCampaignRollup () {
		
        string txtfield1 = 'Title';
        double txtfield1lvl = 6;
        string txtfield1FV = 'Board Member';
		GW_BATCH_EngagementRollup.setSettingsForTests(txtfield1, txtfield1FV, txtfield1lvl);
		
		// first hierarchy
		Campaign top1 = new Campaign (name = 'top1');
		insert top1;
		Campaign child_1a = new Campaign (name = 'child_1a',ParentId = top1.Id,Leadership_Level__c = '3 - lvl three');
		insert child_1a;
		Campaign grandchild_1aa = new Campaign (name = 'grandchild_1aa',ParentId = child_1a.Id,Leadership_Level__c = '3 - lvl three',StartDate=System.Today().addDays(-30));
		insert grandchild_1aa;
		Campaign grandchild_1ab = new Campaign (name = 'grandchild_1ab',ParentId = child_1a.Id,Leadership_Level__c = '1 - lvl one');
		insert grandchild_1ab;
		Campaign child_1b = new Campaign (name = 'child_1b',ParentId = top1.Id,Leadership_Level__c = '3 - lvl three');
		insert child_1b;
		Campaign grandchild_1ba = new Campaign (name = 'grandchild_1ba',ParentId = child_1b.Id,Leadership_Level__c = '3 - lvl three',StartDate=System.Today().addDays(-30));
		insert grandchild_1ba;
		Campaign greatgrand_1baa = new Campaign (name = 'greatgrand_1baa',ParentId = grandchild_1ba.Id,Leadership_Level__c = '3 - lvl three',StartDate=System.Today().addDays(-30));
		insert greatgrand_1baa;
		Campaign greatgrand_1bab = new Campaign (name = 'greatgrand_1bab',ParentId = grandchild_1ba.Id,Leadership_Level__c = '4 - lvl four',StartDate=System.Today().addDays(-30));
		insert greatgrand_1bab;
		Campaign greatgreatgrand_1baaa = new Campaign (name = 'greatgreatgrand_1baaa',ParentId = greatgrand_1baa.Id,Leadership_Level__c = '3 - lvl three',StartDate=System.Today().addDays(-30));
		insert greatgreatgrand_1baaa;
		
		// 2nd hierarchy, just one campaign
		Campaign top2 = new Campaign (name = 'top2', Leadership_Level__c = '4 - lvl four',StartDate=System.Today().addDays(-30));
		insert top2;
		
		
		Id[] allCampIds = new Id[] {top1.Id,child_1a.Id,grandchild_1aa.Id,grandchild_1ab.Id,top2.Id,child_1b.Id,grandchild_1ba.Id,greatgrand_1baa.Id,greatgrand_1bab.Id,greatgreatgrand_1baaa.Id};
		
		// create cons
        Contact[] cons = ONEN_UnitTestData.CreateMultipleTestContacts(20);
        insert cons;
        
        // spoof history for several cons, for conversion rate
        // first a few that will not be conversions or candidates, since have same or higher rate already 
        cons[1].Engagement_Level_Numeric__c = 3;
        cons[1].Engagement_Peak_Numeric__c = 3;
        cons[1].Last_Engagement_Lvl_Chg_Datestamp__c = system.Now().addMonths(-3); 
        cons[10].Engagement_Level_Numeric__c = 4;
        cons[10].Engagement_Peak_Numeric__c = 4;
        cons[10].Last_Engagement_Lvl_Chg_Datestamp__c = system.Now().addMonths(-3);
        cons[14].Engagement_Level_Numeric__c = 3;
        cons[14].Engagement_Peak_Numeric__c = 3;
        cons[14].Last_Engagement_Lvl_Chg_Datestamp__c = system.Now().addMonths(-3);
        // then one that will not be conversion or cand, since level changed too recently
        cons[6].Engagement_Level_Numeric__c = 1;
        cons[6].Engagement_Peak_Numeric__c = 1;
        cons[6].Last_Engagement_Lvl_Chg_Datestamp__c = system.Now().addDays(-2);
        update cons;
        
        // create a few leads
        Lead lead1 = new Lead (FirstName='Lead1',LastName='Test',Company='Foo');
        Lead lead2 = new Lead (FirstName='Lead2',LastName='Test',Company='Foo');
        Lead lead3 = new Lead (FirstName='Lead3',LastName='Test',Company='Foo');
        insert new Lead[] {lead1,lead2,lead3};
        
        
        // first few cons responded on parent, all but 1 is conversion
        set<id> con0thru2 = new set<id> {cons[0].Id,cons[1].Id,cons[2].Id} ;
        set<id> con1nonConv = new set<id> {cons[1].Id} ;
        insert testCMs(child_1a.Id,con0thru2,'Responded',con1nonConv);
        
        // and one lead on the parent (unrealistic, but tests that leads are unduped)
        set<id> leads3 = new set<id> {lead3.Id} ;
        insert testLeadCMs(child_1a.Id,leads3,'Sent');
		
		// one of those plus 4 new ones responded on child that counts
        set<id> con2thru6 = new set<id> {cons[2].Id,cons[3].Id,cons[4].Id,cons[5].Id,cons[6].Id} ;
        set<id> con6nonConv = new set<id> {cons[6].Id} ;
        insert testCMs(grandchild_1aa.Id,con2thru6,'Responded',con6nonConv);
		
		// all of those plus 4 new ones responded on chlid that doesn't count
        set<id> con2thru10 = new set<id> {cons[2].Id,cons[3].Id,cons[4].Id,cons[5].Id,cons[6].Id,cons[7].Id,cons[8].Id,cons[9].Id,cons[10].Id} ;
        set<id> con6and10 = new set<id> {cons[6].Id,cons[10].Id} ;
        insert testCMs(grandchild_1ab.Id,con2thru10,'Responded',con6and10);

		// and 4 more that didn't respond on same campaign
        set<id> con11thru14 = new set<id> {cons[11].Id,cons[12].Id,cons[13].Id,cons[14].Id} ;
        set<id> nullSet = new set<id>();
        insert testCMs(grandchild_1ab.Id,con11thru14,'Sent',nullSet);

		// and finally that one gets a few leads, one of which is responded (email click-through)
		set<id> leads12 = new set<id> {lead1.Id,lead2.Id} ;
		insert testLeadCMs(grandchild_1ab.Id,leads12,'Sent');
		insert testLeadCMs(grandchild_1ab.Id,leads3,'Responded');

		// put a few responders in other branch of hierarchy
        set<id> con1and6 = new set<id> {cons[1].Id,cons[6].Id} ;
        insert testCMs(greatgrand_1baa.Id,con1and6,'Responded',con1and6);
		
		// and a few in its sibling
        set<id> con18and19 = new set<id> {cons[18].Id,cons[19].Id} ;
        insert testCMs(greatgrand_1bab.Id,con18and19,'Responded',nullSet);
		
		//and finally a few at the lowest (5 levels deep) child		
        set<id> con15thru17 = new set<id> {cons[15].Id,cons[16].Id,cons[17].Id} ;
        insert testCMs(greatgreatgrand_1baaa.Id,con6and10,'Responded',con6and10);
        insert testCMs(greatgreatgrand_1baaa.Id,con15thru17,'Sent',nullSet);
        set<id> con7 = new set<id> {cons[7].Id} ;
        insert testCMs(greatgreatgrand_1baaa.Id,con7,'Responded',nullSet);
        		
		// 2 thru 6 also in 2nd hierarchy, not responded        
        insert testCMs(top2.Id,con2thru6,'Sent',nullSet);
        
        // and a few cons that weren't in hierarchy 1 at all, responded
        insert testCMs(top2.Id,con15thru17,'Responded',nullSet);
        
        
        
        // run batch
        // we'd like to do this w/ a small batch size to test spanning of batches, but SF only lets you run one batch from w/in test
        Test.StartTest();
        GW_BATCH_CampaignEngagementRollup myba = new GW_BATCH_CampaignEngagementRollup ();
        ID batchprocessid = Database.executeBatch(myba);
        Test.StopTest();
        
        // make sure rollup is correct
        map<id,Campaign> campMap = new map<id,Campaign> ([SELECT Id,Name,ParentId,Total_Unique_Contacts_In_Hierarchy__c,
        					Total_Unique_Responses_in_Hierarchy__c,Engagement_Response_Rate__c,Engagement_Conversion_Rate__c,
        					Total_Unique_Leads_in_Hierarchy__c 
        					FROM Campaign WHERE Id IN :allCampIds]);
        					
        Campaign top1p = campMap.get(top1.Id);
        system.assertEquals (20,top1p.Total_Unique_Contacts_In_Hierarchy__c);
        system.assertEquals (3,top1p.Total_Unique_Leads_in_Hierarchy__c);
        system.assertEquals (14,top1p.Total_Unique_Responses_in_Hierarchy__c);
        system.assertEquals (null,top1p.Engagement_Response_Rate__c);
        system.assertEquals (null,top1p.Engagement_Conversion_Rate__c);
        					
        Campaign sub1aP = campMap.get(child_1a.Id);
        system.assertEquals (15,sub1aP.Total_Unique_Contacts_In_Hierarchy__c);
        system.assertEquals (3,sub1aP.Total_Unique_Leads_in_Hierarchy__c);
        system.assertEquals (12,sub1aP.Total_Unique_Responses_in_Hierarchy__c);
        system.assertEquals (38.9,sub1aP.Engagement_Response_Rate__c);
        system.assertEquals (35.7,sub1aP.Engagement_Conversion_Rate__c);
        					
        Campaign subsub1aaP = campMap.get(grandchild_1aa.Id);
        system.assertEquals (5,subsub1aaP.Total_Unique_Contacts_In_Hierarchy__c);
        system.assertEquals (0,subsub1aaP.Total_Unique_Leads_in_Hierarchy__c);
        system.assertEquals (5,subsub1aaP.Total_Unique_Responses_in_Hierarchy__c);
        system.assertEquals (100,subsub1aaP.Engagement_Response_Rate__c);
        system.assertEquals (100,subsub1aaP.Engagement_Conversion_Rate__c);
        					
        Campaign subsub1abP = campMap.get(grandchild_1ab.Id);
        system.assertEquals (13,subsub1abP.Total_Unique_Contacts_In_Hierarchy__c);
        system.assertEquals (3,subsub1abP.Total_Unique_Leads_in_Hierarchy__c);
        system.assertEquals (10,subsub1abP.Total_Unique_Responses_in_Hierarchy__c);
        system.assertEquals (62.5,subsub1abP.Engagement_Response_Rate__c);
        system.assertEquals (53.8,subsub1abP.Engagement_Conversion_Rate__c);

        Campaign child_1bP = campMap.get(child_1b.Id);
        system.assertEquals (9,child_1bP.Total_Unique_Contacts_In_Hierarchy__c);
        system.assertEquals (0,child_1bP.Total_Unique_Leads_in_Hierarchy__c);
        system.assertEquals (6,child_1bP.Total_Unique_Responses_in_Hierarchy__c);
        system.assertEquals (66.7,child_1bP.Engagement_Response_Rate__c);
        system.assertEquals (50,child_1bP.Engagement_Conversion_Rate__c);

        Campaign grandchild_1baP = campMap.get(grandchild_1ba.Id);
        system.assertEquals (9,grandchild_1baP.Total_Unique_Contacts_In_Hierarchy__c);
        system.assertEquals (0,grandchild_1baP.Total_Unique_Leads_in_Hierarchy__c);
        system.assertEquals (6,grandchild_1baP.Total_Unique_Responses_in_Hierarchy__c);
        system.assertEquals (66.7,grandchild_1baP.Engagement_Response_Rate__c);
        system.assertEquals (50,grandchild_1baP.Engagement_Conversion_Rate__c);

        Campaign greatgrand_1baaP = campMap.get(greatgrand_1baa.Id);
        system.assertEquals (7,greatgrand_1baaP.Total_Unique_Contacts_In_Hierarchy__c);
        system.assertEquals (0,greatgrand_1baaP.Total_Unique_Leads_in_Hierarchy__c);
        system.assertEquals (4,greatgrand_1baaP.Total_Unique_Responses_in_Hierarchy__c);
        system.assertEquals (57.1,greatgrand_1baaP.Engagement_Response_Rate__c);
        system.assertEquals (25,greatgrand_1baaP.Engagement_Conversion_Rate__c);

        Campaign greatgrand_1babP = campMap.get(greatgrand_1bab.Id);
        system.assertEquals (2,greatgrand_1babP.Total_Unique_Contacts_In_Hierarchy__c);
        system.assertEquals (0,greatgrand_1babP.Total_Unique_Leads_in_Hierarchy__c);
        system.assertEquals (2,greatgrand_1babP.Total_Unique_Responses_in_Hierarchy__c);
        system.assertEquals (100,greatgrand_1babP.Engagement_Response_Rate__c);
        system.assertEquals (100,greatgrand_1babP.Engagement_Conversion_Rate__c);

        Campaign greatgreatgrand_1baaaP = campMap.get(greatgreatgrand_1baaa.Id);
        system.assertEquals (6,greatgreatgrand_1baaaP.Total_Unique_Contacts_In_Hierarchy__c);
        system.assertEquals (0,greatgreatgrand_1baaaP.Total_Unique_Leads_in_Hierarchy__c);
        system.assertEquals (3,greatgreatgrand_1baaaP.Total_Unique_Responses_in_Hierarchy__c);
        system.assertEquals (50,greatgreatgrand_1baaaP.Engagement_Response_Rate__c);
        system.assertEquals (25,greatgreatgrand_1baaaP.Engagement_Conversion_Rate__c);

        					
        Campaign top2P = campMap.get(top2.Id);
        system.assertEquals (8,top2P.Total_Unique_Contacts_In_Hierarchy__c);
        system.assertEquals (0,top2P.Total_Unique_Leads_in_Hierarchy__c);
        system.assertEquals (3,top2P.Total_Unique_Responses_in_Hierarchy__c);
        system.assertEquals (37.5,top2P.Engagement_Response_Rate__c);
        system.assertEquals (42.9,top2P.Engagement_Conversion_Rate__c);
        					
       	
        
		
	}
	
	static list<CampaignMember> testCMs (Id CampId, Set<id> ConIDs, string statusStr, Set<Id> conIDsNotConversions ) {
		// create a campaignmember object, including spoofing whether or not it's a conversion
		CampaignMember[] cms = new CampaignMember[0]; 
		for (Id conId : ConIDs) {
			CampaignMember cm = new CampaignMember (CampaignId = CampId,ContactId = conId, Status = statusStr);
			if (statusStr != 'Responded' || conIDsNotConversions.contains(conId)) {
				cm.Engagement_Conversion__c = false;
			} else {
				cm.Engagement_Conversion__c = true;
			}
			cms.add (cm);
		}
		return cms;
 	}
 	
 	static list<CampaignMember> testLeadCMs (Id CampId, Set<id> LeadIds, string statusStr) {
		// create a campaignmember object, including spoofing whether or not it's a conversion
		CampaignMember[] cms = new CampaignMember[0]; 
		for (Id lid : LeadIds) {
			CampaignMember cm = new CampaignMember (CampaignId = CampId,LeadId = lid, Status = statusStr);
			cms.add (cm);
		}
		return cms;
 	}


}