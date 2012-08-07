trigger GW_CampaignTriggerBefore on Campaign (before insert) {

	list<EngagementCampaignSettings__c> listECS = EngagementCampaignSettings__c.getall().values();
	if (listECS.size() > 0) {
		
		// load up the batch class to gain access to the level name map.
		GW_BATCH_EngagementRollup cBER = new GW_BATCH_EngagementRollup(false);

		for (Campaign cmp : trigger.new) {
			// only set default level if none is set.
			if (cmp.Leadership_Level__c == null) {
				// we compare each campaign to all of the campaign settings
				for (EngagementCampaignSettings__c ecs : listECS) {
					if ((ecs.Campaign_Record_Type__c == null || ecs.Campaign_Record_Type__c == '' || ecs.Campaign_Record_Type__c == cmp.get('RecordTypeId')) &&
						(ecs.Campaign_Type__c == null || ecs.Campaign_Type__c == '' || ecs.Campaign_Type__c == cmp.Type) &&
						(ecs.Campaign_Sub_Type__c == null || ecs.Campaign_Sub_Type__c == '' || 
							!GW_GWEngageUtilities.IsGWBaseInstalled || 
							ecs.Campaign_Sub_Type__c == cmp.get(GW_GWEngageUtilities.addNSPrefixET('Campaign_Sub_Type__c', false, false)))						
						) {
						cmp.Leadership_Level__c = cBER.lvlNameMap.get(integer.valueOf(ecs.Engagement_Level__c));
					}
				}		
			}
		}	
	}
}