// Written by Matthew Scholtz, copyright (c) 2007 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

/*******************************************************************************************************
* @author Matthew Scholtz
* @date 01/01/2007
* @description ONEN_UnitTestData is a class that handles data for use in unit test code. These methods
* should not be used by production code.
* test
*/
public class ONEN_UnitTestData { 

	/*******************************************************************************************************
	* @description Method that creates a Contact for use in unit test code.
	* @param n Identifies unique set of Contact field values for n values 1, 2 and 3.
	* @return A Contact record.
	*/
/******************** NOT USED (yet)
	public static contact CreateTestContact (integer n) {
		
		// create one contact
		// integer identifies unique set of field values
		
		Contact newCon = New Contact ();
		
		if ( n == 1 ) {
			newCon.FirstName = 'Stringer';
			newCon.LastName = 'Bell';
			newCon.OtherCity = 'Baltimore';
		} else if (n==2) {
			newCon.FirstName = 'Avon';
			newCon.LastName = 'Barksdale';
			newCon.OtherCity = 'Baltimore';
		} else if (n==3) {
			newCon.FirstName = 'Lester';
			newCon.LastName = 'Freamon';
			newCon.OtherCity = 'Baltimore';
		}
		
//		insert newCon;
		return newCon;
	}
*************************/
	
	/*******************************************************************************************************
	* @description Method that creates a list of Contacts for use in unit test code.
	* @param n The number of Contacts to be added to the list.
	* @return A list of Contact records of size n.
	*/
	public static list<Contact> CreateMultipleTestContacts (integer n) {
		
		list<contact> ContactsToAdd = New list<contact> ();
		
		for (integer i=0;i<n;i++) {
			Contact newCon = New Contact (
				FirstName = 'Number' + i,
				LastName = 'Doppleganger',
				OtherCity = 'Seattle'
			);
			ContactsToAdd.add (newCon);
		}
		
		// testing doing the insert in the calling code - will maybe reinstate this
		//insert ContactsToAdd;
		
		return ContactsToAdd;
	}

	/*******************************************************************************************************
	* @description Method that creates a partner Contact and a Household for each Contact in a list, for use 
	* in unit test code.
	* @param firstContactList A list of contacts.
	* @return A list of contacts, with each contact being in a household with the respective contact from firstContactList.
	*/
	public static list<Contact> CreateMultipleTestContactsInHouseholds (List<Contact> firstContactList) {
		
		list<contact> ContactsToAdd = New list<contact> ();
		list<contact> SourceContacts = firstContactList;		
		if (GW_BATCH_EngagementRollup.IsNPSPHHInstalled) {	
			SourceContacts = database.query('select Id, npo02__Household__c, npo02__Household__r.Id from contact where Id in :firstContactList');
		}
		
		for (integer i=0;i<SourceContacts.size();i++) {
			Contact newCon = New Contact (
				FirstName = 'Second Number' + i,
				LastName = 'Doppleganger',
				OtherCity = 'Seattle'
				//DH ,ONEN_Household__c = firstContactList[i].ONEN_Household__c
			);
			if (GW_BATCH_EngagementRollup.IsNPSPHHInstalled) {	
				
				sObject hh = SourceContacts[i].getSObject('npo02__Household__r');
				system.assert(hh != null);  
				if (hh != null) {
					newCon.put('npo02__Household__c', hh.get('Id'));
				}
			}
			
			ContactsToAdd.add (newCon);
		}
		
		// testing doing the insert in the calling code - will maybe reinstate this
		//insert ContactsToAdd;
		
		return ContactsToAdd;
	}

	/*******************************************************************************************************
	* @description Method that creates one Opportunity each to a given list of Contacts for use in unit test 
	* code. 
	* @param Cons A list of Contacts to add Opportunities to.
	* @param CampId A Campaign ID to link Opportunities to.
	* @param Stage An Opportunity stage.
	* @param Close An Opportunity closing date.
	* @param Amt An Opportunity amount.
	* @param rectype A record type.
	* @param oppType An Opportunity type.
	* @return A list of Opportunities associated with Cons.
	*/
	public static list<Opportunity> OppsForContactList (list<Contact> Cons, id CampId, string Stage, date Close, double Amt, string rectype, string oppType) {
	 
		// given a list of Contacts,
		// add one Opp per contact w/ the specified data
		// TBD should allow specifying rectype (optional)
	
		list<Opportunity> OppsToAdd = new list<Opportunity> ();
		id rtid = GW_RecTypes.GetRecordTypeId ('Opportunity',rectype);
		
		for ( Contact thisCon : Cons ) {
			Opportunity newOpp = New Opportunity (
				Name = 'Test Opp ' + thisCon.FirstName + thisCon.LastName,
				Amount = Amt,
				CloseDate = Close, 
				StageName = Stage,
				CampaignId = CampId,
				//DH CR_Contact_Id__c = thisCon.Id,
				//DH CR_Contact_Role__c = ONEN_Constants.OPP_GIFT_DONOR_ROLE(GW_RecTypes.getRecordTypeName('Opportunity',rtid)),
				type = oppType,
				RecordTypeId = rtid 
			);	
			if (GW_BATCH_EngagementRollup.IsNPSPHHInstalled) {
				newOpp.put('npe01__Contact_Id_for_Role__c', thisCon.Id);				
			}
			OppsToAdd.add (newOpp);
		}
		
		return OppsToAdd;
		
	}
	
	/*******************************************************************************************************
	* @description Method that returns a list of Accounts for use in unit test code.
	* @param n The number of Accounts to be returned.
	* @return A list of Accounts records of size n.
	*/
/***************** not used	
	public static list<Account> CreateMultipleTestAccounts (integer n) {
		
		list<Account> AcctsToAdd = New list<Account> ();
		
		for (integer i=0;i<n;i++) {
			Account newAcct = New Account (
				Name = 'Yet Another Org ' + i
			);
			AcctsToAdd.add (newAcct);
		}
		
		return AcctsToAdd;
	}
****************/
	
	/*******************************************************************************************************
	* @description Method that returns one Opportunity each for a given list of Accounts.
	* @param Accts A list of Accounts to add Opportunities to.
	* @param CampId A Campaign ID to link Opportunities to.
	* @param Stage An Opportunity stage.
	* @param Close An Opportunity closing date.
	* @param Amt An Opportunity amount.
	* @param rectype A record type.
	* @return A list of Opportunities associated with Accts.
	*/
/************************** not used	
	public static list<Opportunity> OppsForAccountList (list<Account> Accts, id CampId, string Stage, date Close, double Amt, string rectype) {
	
		// given a list of accounts,
		// add one Opp per acct w/ the specified data
	
		list<Opportunity> OppsToAdd = new list<Opportunity> ();
		
		// look up the id for the specified rectype
		id rtid = GW_RecTypes.GetRecordTypeId ('Opportunity',rectype);
		
		for ( Account thisAcct : Accts) {
			Opportunity newOpp = New Opportunity (
				AccountId = thisAcct.id,
				Name = 'Test Opp ' + thisAcct.Name,
				Amount = Amt,
				CloseDate = Close,
				StageName = Stage,
				CampaignId = CampId
				//DH RecordTypeId = rtid
			);	
			OppsToAdd.add (newOpp);
		}
		
		return OppsToAdd;
		
	}
***********************************/

	/*******************************************************************************************************
	* @description Method that returns a Campaign Member for use in unit test code.
	* @param CampId A Campaign ID.
	* @param ConId A Contact ID.
	* @param CMStatus A Campaign Member Status.
	* @return A list of Accounts records of size n.
	*/
	public static CampaignMember CreateCampaignMember (id CampId, id ConId, string CMStatus) {
	
		CampaignMember newCM = new CampaignMember (
			CampaignId = CampId,
			ContactId = ConId,
			Status = CMStatus
		);
		
		insert newCM;
		return newCm;	
		
	}
	
	/*******************************************************************************************************
	* @description Method that deletes all records in a custom setting table.
	* @param objname A custom setting table.
	*/
	public static void DeleteListCustomSettingRecs (string objname) {
		// given the name of a custom setting table, delete all the records in it
        string qstr = 'SELECT Id,Name FROM ' + objname;
        sObject[] srecs = Database.query(qstr);
        if (srecs.size() > 0) {
        	// first make sure this is really a custom setting obj
        	Schema.Sobjecttype t = srecs[0].getSObjectType();
        	Schema.Describesobjectresult d = t.getDescribe();
        	if ( d.isCustomSetting() ) {
        		// if so, delete all the recs
        		delete srecs;
        	}
        }
	}
	static testmethod void TestTheTestData() {
		
		test.startTest();
		list<Contact> listCon = CreateMultipleTestContacts(10); 
		insert listCon;
		
		list<Opportunity> listOpp = OppsForContactList (listCon, null, 'Closed Won', system.today(), 100, 			
			ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, null);
		insert listOpp;
		system.debug(listOpp);

		date dtMbr = system.today().addMonths(-11);
		list<Opportunity> listOppMbr = OppsForContactList (listCon, null, 'Closed Won', dtMbr, 15, 			
			ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS, null);
		if (GW_BATCH_EngagementRollup.IsNPSPHHInstalled) {
			for (Opportunity opp : listOppMbr) {
	        	opp.put('npe01__Membership_Start_Date__c', opp.CloseDate);
	        	opp.put('npe01__Membership_End_Date__c', opp.CloseDate.AddYears(1)); 
			}
		}
		insert listOppMbr;
		system.debug(listOppMbr);		

		if (GW_BATCH_EngagementRollup.IsNPSPHHInstalled) {
			list<OpportunityContactRole> listOCR = [SELECT Id, IsPrimary, Role, OpportunityId, ContactId FROM OpportunityContactRole
				WHERE  OpportunityId in :listOpp or OpportunityId in :listOppMbr];
			system.assertEquals(listOpp.size() + listOppMbr.size(), listOCR.size());
		}
				
		// call this to allow future rollups to proceed.
		test.stopTest();
		
		
		string strSoql = 'SELECT Id, Name,';
		if (GW_BATCH_EngagementRollup.IsNPSPHHInstalled) {
			strSoql += 'npo02__OppAmountLastNDays__c, npo02__LastCloseDate__c, npo02__TotalOppAmount__c, npo02__Household__c, ' +
				'npo02__LastCloseDateHH__c, npo02__OppsClosedLastNDays__c, npo02__Household__r.npo02__OppAmountLastNDays__c, ' +
				'npo02__Household__r.npo02__OppsClosedLastNDays__c, npo02__Household__r.npo02__LastMembershipDate__c, ' +
				'npo02__MembershipJoinDate__c, npo02__MembershipEndDate__c, npo02__LastMembershipLevel__c, ' +
				'npo02__LastMembershipOrigin__c, npo02__LastMembershipDate__c, npo02__LastMembershipAmount__c,';
		}
        strSoql = strSoql.substring(0,strSoql.length()-1);   //lop off trailing comma
		strSoql += ' FROM Contact where Id in :listCon';

        listCon = Database.query(strSoql);
        for (Contact con : listCon) {
			if (GW_BATCH_EngagementRollup.IsNPSPHHInstalled) {
				// we don't know if membership is included in donation rollups or not.
				system.assert(con.get('npo02__OppAmountLastNDays__c') == 100 ||
					con.get('npo02__OppAmountLastNDays__c') == 115);
				system.assertEquals(system.today(), con.get('npo02__LastCloseDate__c'));
				system.assertEquals(15, con.get('npo02__LastMembershipAmount__c'));
				system.assertEquals(dtMbr, con.get('npo02__LastMembershipDate__c'));
				system.assertEquals(dtMbr, con.get('npo02__MembershipJoinDate__c'));
				system.assertEquals(dtMbr.AddYears(1), con.get('npo02__MembershipEndDate__c'));
			}
		}
		
	}	
}