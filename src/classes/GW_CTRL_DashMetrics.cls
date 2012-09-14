public with sharing class GW_CTRL_DashMetrics {

	public integer ttlConversions {
		get {
			if (!convCalcDone) calcConvTotals();
			return ttlConversions;
		}
		set;
	}
	public integer oppConversions {
		get {
			calcConvTotals();
			return oppConversions;
		}
		set;
	}
	public integer campConversions {
		get {
			calcConvTotals();
			return campConversions;
		}
		set;
	}
	public integer ttlListGrowthRecent {
		get {
			calcRecentListGrowth();
			return ttlListGrowthRecent;
		}
		set;
	}
	public integer ttlListGrowthPrev90 {
		get {
			calcRecentListGrowth();
			return ttlListGrowthPrev90;
		}
		set;
	}
	public integer ttlNewDonors {
		get {
			calcRecentNewDonors();
			return ttlNewDonors;
		}
		set;
	}
	public integer ttlNewDonorsPrev90 {
		get {
			calcRecentNewDonors();
			return ttlNewDonorsPrev90;
		}
		set;
	}
	
	final integer MAX_LEVEL_LOW_LEVEL_LIST_GROWTH = 2;
	date ninetyDayCutoff;
	date oneEightyDayCutoff;
	boolean convCalcDone = false;
	boolean listGrowthCalcDone = false;
	boolean newDonorCalcDone = false;
	string linkReportName;
	
	GW_GWEngageUtilities.debugLogger dlog = new GW_GWEngageUtilities.debugLogger();
	
	public GW_CTRL_DashMetrics() {
		this.ninetyDayCutoff = system.today().addDays(-90);
		this.oneEightyDayCutoff = system.today().addDays(-180);
	}

	private void calcConvTotals() {
		if (!convCalcDone) {
			
			string engConvFieldname = GW_GWEngageUtilities.addNSPrefixET('Engagement_Conversion__c', true, false);
			string effDateFieldname = GW_GWEngageUtilities.addNSPrefixET('Effective_Action_Date__c', true, false);
			
			// tbd add namespace prefixes
			string soql = 'SELECT Count() FROM Opportunity WHERE CloseDate >= :ninetyDayCutoff AND ' + engConvFieldname + ' = true ';
			integer count1 = database.countQuery(soql);
			oppConversions = (count1==null) ? 0 : count1;
	
			string soql2 = 'SELECT Count() FROM CampaignMember WHERE ' + effDateFieldname + ' >= :ninetyDayCutoff AND ' 
							+ engConvFieldname + ' = true ';
			integer count2 = database.countQuery(soql2);
			campConversions = (count2==null) ? 0 : count2;
			
			ttlConversions = count1 + count2;
			
			convCalcDone = true;
		}

	}
	
	private void calcRecentListGrowth() {
		if (!listGrowthCalcDone) {
			string firstEngDateFieldname = GW_GWEngageUtilities.addNSPrefixET('First_Engagement_Level_Date__c', true, false);			
			string firstEngLvlFieldname = GW_GWEngageUtilities.addNSPrefixET('First_Engagement_Level__c', true, false);			

			string soql1 = 'SELECT Count() FROM Contact WHERE ' + firstEngDateFieldname + ' >= :ninetyDayCutoff AND ' 
							+ firstEngLvlFieldname + ' > 0 AND ' + firstEngLvlFieldname + ' <= :MAX_LEVEL_LOW_LEVEL_LIST_GROWTH';
			integer count1 = database.countQuery(soql1);
			ttlListGrowthRecent = (count1==null) ? 0 : count1;
	
			string soql2 = 'SELECT Count() FROM Contact WHERE ' + firstEngDateFieldname + ' < :ninetyDayCutoff AND ' 
							+ firstEngDateFieldname + ' >= :oneEightyDayCutoff AND ' + firstEngLvlFieldname + ' > 0 AND ' + firstEngLvlFieldname + ' <= :MAX_LEVEL_LOW_LEVEL_LIST_GROWTH';
			integer count2 = database.countQuery(soql2);
			ttlListGrowthPrev90 = (count2==null) ? 0 : count2;
			
			listGrowthCalcDone = true;
		} 
	}


	private void calcRecentNewDonors() {
		linkReportName = 'Recent New Donors';
		
		if (!newDonorCalcDone) {
			
			string firstDonDateFieldname = GW_GWEngageUtilities.addNSPrefixET('First_Donation_Date__c', true, false);			

			string soql1 = 'SELECT Count() FROM Contact WHERE ' + firstDonDateFieldname + ' >= :ninetyDayCutoff'; 
			integer count1 = database.countQuery(soql1);
			ttlNewDonors = (count1==null) ? 0 : count1;
	
			string soql2 = 'SELECT Count() FROM Contact WHERE ' + firstDonDateFieldname + ' < :ninetyDayCutoff AND ' 
							+ firstDonDateFieldname + ' >= :oneEightyDayCutoff';
			integer count2 = database.countQuery(soql2);
			ttlNewDonorsPrev90 = (count2==null) ? 0 : count2;
			
			newDonorCalcDone = true;
		} 
	}


	public pageReference getReportLinkNewDonors () {
		// tbd should refactor this so don't need separate methods, but since isn't an onclick need to get the URL on page load for now
		return reportURL ('Recent New Donors');
	}

	public pageReference getReportLinkCampaignConversions () {
		// tbd should refactor this so don't need separate methods, but since isn't an onclick need to get the URL on page load for now
		return reportURL ('Recent Campaign Engagement Conversions');
	}

	public pageReference getReportLinkListGrowth () {
		// tbd should refactor this so don't need separate methods, but since isn't an onclick need to get the URL on page load for now
		return reportURL ('Recent New Low level Supporters');
	}

	private pageReference reportURL(string rptName) {
		// given a report name, return the URL
		Report r = [SELECT Id FROM Report WHERE Name = :rptName LIMIT 1];
		if (r != null) {
			PageReference ref = new PageReference('/' + r.Id);
            ref.setRedirect(true);
 	        return ref;
        } else {
        	return null;
 		}
	}


	static testmethod void testconv() {
		GW_CTRL_DashMetrics obj = new GW_CTRL_DashMetrics();
		integer convs = obj.ttlConversions;
		integer growth = obj.ttlListGrowthRecent;
		integer newDonors = obj.ttlNewDonors;
	}

}