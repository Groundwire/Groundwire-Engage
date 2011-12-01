public with sharing class ONEN_Constants {

	/*******************************************************************************************************
	* @description Returns the custom setting Opp_Rectype_For_Tests_Default__c, a record type for 
	* Opportunities. Defaults to 'Donation'.
	*/
	public static string OPP_DEFAULT_RECTYPE_FORTESTS {
		get {
			if (GW_BATCH_EngagementRollup.settings.Opp_Rectype_For_Tests_Default__c == null) {
				return 'Donation';
			}
			return (GW_BATCH_EngagementRollup.settings.Opp_Rectype_For_Tests_Default__c);
		}
	}		

	/*******************************************************************************************************
	* @description Returns the custom setting Opp_Rectype_For_Tests_Member__c, a record type for 
	* Opportunities used in membership testing. Defaults to 'Membership'.
	*/
	public static string OPP_MEMBER_RECTYPE_FORTESTS {
		get {
			if (GW_BATCH_EngagementRollup.settings.Opp_Rectype_For_Tests_Member__c == null) {
				return 'Membership';
			}
			return (GW_BATCH_EngagementRollup.settings.Opp_Rectype_For_Tests_Member__c);
		}
	}		


}