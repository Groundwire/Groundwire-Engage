trigger GW_ContactTriggerBefore on Contact (before insert, before update) {
    
    // when engagement lvl override gets set, apply the default time limit unless user has specified otherwise
    GW_BATCH_EngagementRollup.ContactEngagementLvlOverride();
    
    // if peak level or any of the other "persistent" engagement cals are present on insert, blank them out
    if (trigger.isInsert) {
    	for (Contact con : trigger.new) {
    		con.Engagement_Peak_Numeric__c = null;
    		con.Engagement_Peak__c = null;
    		con.Last_Engagement_Lvl_Chg_Datestamp__c = null;
    		con.gwet__Former_Engagement_Level_Numeric__c = null;
    	}
    }
}