trigger GW_CampaignTriggerBefore on Campaign (before insert) {

	list<EngagementCampaignSettings__c> listECS = EngagementCampaignSettings__c.getall().values();
	if (listECS.size() > 0) {
		
		// load up the Campaign Engagement Levels
		map<integer, string> mapLevelNumToLevelName = new map<integer, string>();
		for (Schema.PicklistEntry p : Campaign.Leadership_Level__c.getDescribe().getPicklistValues()) {
			mapLevelNumToLevelName.put(integer.valueOf(p.getValue().substring(0,1)), p.getLabel());		
		}				
			
		for (Campaign cmp : trigger.new) {
			// only set default level if none is set.
			if (cmp.Leadership_Level__c == null) {
				// we compare each campaign to all of the campaign settings
				for (EngagementCampaignSettings__c ecs : listECS) {
					if ((ecs.Campaign_Record_Type__c == null || ecs.Campaign_Record_Type__c == '' || ecs.Campaign_Record_Type__c == cmp.get('RecordTypeId')) &&
						(ecs.Campaign_Type__c == null || ecs.Campaign_Type__c == '' || ecs.Campaign_Type__c == cmp.Type) &&
						(ecs.Campaign_Sub_Type__c == null || ecs.Campaign_Sub_Type__c == '' || 
							!GW_BATCH_EngagementRollup.IsGWBaseInstalled || 
							ecs.Campaign_Sub_Type__c == cmp.get(GW_BATCH_EngagementRollup.addNSPrefixET('Campaign_Sub_Type__c', false, false)))						
						) {
						cmp.Leadership_Level__c = mapLevelNumToLevelName.get(integer.valueOf(ecs.Engagement_Level__c));
					}
				}		
			}
		}	
	}
}