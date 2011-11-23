trigger GW_ContactTriggerBefore on Contact (before insert, before update) {
    
    // when engagement lvl override gets set, apply the default time limit unless user has specified otherwise
    GW_BATCH_EngagementRollup.ContactEngagementLvlOverride();
}