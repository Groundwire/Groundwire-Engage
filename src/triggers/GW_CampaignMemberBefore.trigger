trigger GW_CampaignMemberBefore on CampaignMember (before insert) {

	// record contact's level at time of campaign member creation
	if (trigger.isInsert) {
		set<id> conIds = new set<id>();
		for (CampaignMember cm : trigger.new) {
			// first gather contact Id's for our CM's
			if (cm.ContactId != null) {
				conIds.add(cm.ContactId);
			}
		}
		if (conIds.size() > 0 ) {
			// then query for the contacts to get engagement lvls
			map <id,Contact> conMap = new map <id,Contact> ([SELECT Id,Engagement_Level_Numeric__c,Last_Engagement_Lvl_Chg_Datestamp__c FROM Contact WHERE Id IN :conIds]);
			// and finally loop back thru CM's and assign
			for (CampaignMember cm : trigger.new) {
				if (cm.ContactId != null) {
					Contact con = conMap.get(cm.ContactId);
					if (con != null) {
						cm.Engagement_Level_At_Insert__c = (con.Engagement_Level_Numeric__c > 0) ? con.Engagement_Level_Numeric__c : 0;
						cm.Level_Change_Datestamp_At_Insert__c = con.Last_Engagement_Lvl_Chg_Datestamp__c;
					}
				}
			}
		}
	}

}