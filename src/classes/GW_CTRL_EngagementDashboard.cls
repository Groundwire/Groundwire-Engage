public with sharing class GW_CTRL_EngagementDashboard {


	// public list<sobject> aggResults {get;set;}
	public list<aggEngagementRow> rows {get;set;}
	public boolean noRecentData {get;set;}

	// constructor
	public GW_CTRL_EngagementDashboard () {
		this.rows = new list<aggEngagementRow>();
		queryEngagementCounts();
		
	}
	
	
	public void queryEngagementCounts () {
		
		// get the most recent day's totals from the analytic snapshot
		// first find out the most recent date we have data for - should be today unless early in the a.m. 
		Engagement_Totals__c[] lastTotals = [SELECT Id,As_of_Date__c FROM Engagement_Totals__c ORDER BY As_of_Date__c DESC LIMIT 1];
		if (lastTotals.size() == 0) {
			noRecentData = true;
		} else {
			date lastDate = lastTotals[0].As_of_Date__c;
			if (lastDate.daysBetween(System.today()) > 7) {
				noRecentData = true;
			}  else {
				// query for all the totals from that date
				Engagement_Totals__c[] results = [Select Engagement_Level__c, Number_of_Contacts__c  
					FROM Engagement_Totals__c WHERE As_of_Date__c = :lastDate
					ORDER BY Engagement_Level__c];
				
				for (Engagement_Totals__c result:results) {
					aggEngagementRow row = new aggEngagementRow();
					row.levelName = result.Engagement_Level__c;
					row.countCons = (integer) result.Number_of_Contacts__c;
					rows.add(row);
				}
			}
		}		
	}
	
	
	//wrapper class
	public class aggEngagementRow {
		
		public string levelName {get;set;}
		public integer countCons {get;set;} 
		
	}
	
    //--------------------TEST METHOD------------------------
    static testMethod void TestIt(){
    	
    	// insert some rows
    	list<Engagement_Totals__c> ets = new list<Engagement_Totals__c>(); 
    	for (integer i=0;i<7;i++) {
    		Engagement_Totals__c et = new Engagement_Totals__c (
    			Engagement_Level__c = (i+1) + ' - the level you love',
    			Number_of_Contacts__c = (i+1) * 100,
    			As_of_Date__c = system.today()
    		);
    		ets.add(et);
    	}
    	insert ets;
    	
        GW_CTRL_EngagementDashboard controller = new GW_CTRL_EngagementDashboard();
        controller.queryEngagementCounts();
        system.debug ('rows:' + controller.rows);
        system.debug ('noRecentData:' + controller.noRecentData);
    }

}