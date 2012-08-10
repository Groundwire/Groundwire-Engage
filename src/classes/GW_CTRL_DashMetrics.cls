public with sharing class GW_CTRL_DashMetrics {

	public integer ttlConversions {get;set;}
	public integer oppConversions {get;set;}
	public integer campConversions {get;set;}
	date ninetyDayCutoff;
	
	public GW_CTRL_DashMetrics() {
		this.ninetyDayCutoff = system.today().addDays(-90);
		calcConvTotals();
	}

	private void calcConvTotals() {
		// tbd add namespace prefixes
		string soql = 'SELECT Count() FROM Opportunity WHERE CloseDate >= :ninetyDayCutoff AND Engagement_Conversion__c = true ';
		oppConversions = database.countQuery(soql);
		if (oppConversions==null) oppConversions = 0; 

		string soql2 = 'SELECT Count() FROM CampaignMember WHERE Effective_Action_Date__c >= :ninetyDayCutoff AND Engagement_Conversion__c = true ';
		campConversions = database.countQuery(soql2);
		if (campConversions==null) campConversions = 0; 
		
		ttlConversions = oppConversions + campConversions;

	}

}