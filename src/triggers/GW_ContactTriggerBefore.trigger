trigger GW_ContactTriggerBefore on Contact (before insert, before update) {
    
    // when engagement lvl override gets set, apply the default time limit unless user has specified otherwise
    GW_GWEngageUtilities.ContactEngagementLvlOverride();
    
    // if peak level or any of the other "persistent" engagement calcs are present on insert, blank them out
    if (trigger.isInsert) {
    	GW_GWEngageUtilities.BlankETConFields(trigger.new);
    }

	/* don't really want to do this in trigger, doesn't accommodate legacy data    
    // if we're in NPSP, set the Donor flag if Total Lifetime giving goes to > 0
    if (trigger.isUpdate && GW_GWEngageUtilities.IsNPSPHHInstalled) {
    	for (Contact con:trigger.new) {
    		string donorFieldname = GW_GWEngageUtilities.addNSPrefixET('IsDonor__c',true,false);
    		decimal totalGifts = (decimal) con.get('npo02__TotalOppAmount__c');
    		boolean isDonor = (boolean) con.get(donorFieldname);
    		if (totalGifts > 0 && isDonor == false) {
    			con.put(donorFieldname,true);
    		}
    	}
    }
    */    
}