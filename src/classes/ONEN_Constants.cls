public with sharing class ONEN_Constants {

	/*******************************************************************************************************
	* @description Returns the custom setting Opp_Rectype_For_Tests_Default__c, a record type for 
	* Opportunities. Defaults to 'Donation'.
	*/
	
	// use the rectype given by the setting, unless we don't have any settings recs.  
	// In that case, use the NPSP if we can find it, else a random existing rectype
	
	public static string OPP_DEFAULT_RECTYPE_FORTESTS {
		get {
	        EngagementTrackerSettings__c settings = EngagementTrackerSettings__c.getValues(UserInfo.getOrganizationId());
	        if (settings == null) {
	        	return defaultOppRectype('Donation');
	        } else {
	        	return settings.Opp_Rectype_For_Tests_Default__c;
	        }
		}
	}		

	/*******************************************************************************************************
	* test
	* @description Returns the custom setting Opp_Rectype_For_Tests_Member__c, a record type for 
	* Opportunities used in membership testing. Defaults to 'Membership'.
	*/
	public static string OPP_MEMBER_RECTYPE_FORTESTS {
		get {
	        EngagementTrackerSettings__c settings = EngagementTrackerSettings__c.getValues(UserInfo.getOrganizationId());
	        if (settings == null) {
	        	return defaultOppRectype('Membership');
	        } else {
	        	return settings.Opp_Rectype_For_Tests_Member__c;
	        }
		}
	}		


	public static string defaultOppRectype (string tryFirst) {
		// first try to find the rectype given in the param
		// if not found, just take the first opp rectype we do find, at random
		string rectypeName;
		id tryID = GW_RecTypes.GetRecordTypeId('Opportunity', tryFirst);
		if (tryID == null) {
			Map<String, Id> rectypeMap = GW_RecTypes.GetRecordTypeIdMap('Opportunity');
			// can't take first element of a set, so cast to a list
			list<string> allRectypeNames = new list<string>();
			allRectypeNames.addAll(rectypeMap.keyset());
			rectypeName = allRectypeNames[0];
		} else {
			rectypeName = tryFirst;
		}
		return rectypeName;
	}

}