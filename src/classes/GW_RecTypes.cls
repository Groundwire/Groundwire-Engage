// Written by Evan Callahan, copyright (c) 2010 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

/*******************************************************************************************************
* @author Evan Callahan
* @date 01/01/2010
* @description GW_RecTypes is a class that is meant to allow for access to Record Type information from
* within other classes.
* It is called statically, and therefore will supply the same information to all calls made from
* within one transaction, or set of trigger calls. This is beneficial because this info should
* be the same for all calls in a transaction, and by calling it statically we reduce the calls
* that are made, making the total transaction more efficient.
*/
public class GW_RecTypes {
	
	//maps to hold the record type info
	private static Map<String, Schema.SObjectType> gd;
	private static Map<String,Map<Id,Schema.RecordTypeInfo>> recordTypesById = new Map<String,Map<Id,Schema.RecordTypeInfo>>();
	private static Map<String,Map<String,Schema.RecordTypeInfo>> recordTypesByName = new Map<String,Map<String,Schema.RecordTypeInfo>>();
		
	/*******************************************
	* Gets record type maps for a new object
	********************************************/
	static void fillMapsForObject(string objectName) {
		// get the object map the first time
		if (gd==null) gd = Schema.getGlobalDescribe(); 
		
		// get the object description
		if (gd.containsKey(objectName)) {
			Schema.DescribeSObjectResult d = gd.get(objectName).getDescribe();
			recordTypesByName.put(objectName, d.getRecordTypeInfosByName());
			recordTypesById.put(objectName, d.getRecordTypeInfosById());
		}
	}

	/*******************************************************************************************************
	* @description Gives record type ID from a given record type name.
	* @param objectName The name of an Object.
	* @param RecordTypeName The name of a Record Type.
	* @return The Record Type's ID.
	*/
	public static Id GetRecordTypeId(String objectName, String RecordTypeName) {
		// make sure we have this object's record types mapped
		if (!recordTypesByName.containsKey(objectName)) 
			fillMapsForObject(objectName);
		
		// now grab and return the requested id	
		Map<String,Schema.RecordTypeInfo> rtMap = recordTypesByName.get(objectName);
		if (rtMap != null && rtMap.containsKey(RecordTypeName)) {
			return rtMap.get(RecordTypeName).getRecordTypeId();
		} else {
			return null;
		}
	}
		
	/*******************************************************************************************************
	* @description Gives record name from a given Record Type ID.
	* @param objectName The name of an Object.
	* @param RecordTypeId The ID of a Record Type.
	* @return The Record Type's name.
	*/
	public static String GetRecordTypeName(String objectName, Id RecordTypeId) {
		// make sure we have this object's record types mapped
		if (!recordTypesById.containsKey(objectName)) 
			fillMapsForObject(objectName);
		
		// now grab and return the requested id
		Map<Id,Schema.RecordTypeInfo> rtMap = recordTypesById.get(objectName);
		if (rtMap != null && rtMap.containsKey(RecordTypeId)) {
			return rtMap.get(RecordTypeId).getName();
		} else {
			return null;
		}
	}

	/*******************************************************************************************************
	* @description Gives a set of record type IDs from a given set of names.
	* @param objectName The name of an Object.
	* @param RecordTypeNameSet A Set of Record Type names.
	* @return A Set of Record Type IDs.
	*/
	public static set<Id> GetRecordTypeIdSet(String objectName, set<string> RecordTypeNameSet) {
		set<Id> recordTypeIds = new set<Id>();

		// make sure we have this object's record types mapped
		if (!recordTypesByName.containsKey(objectName)) 
			fillMapsForObject(objectName);

		// fill the id set from the name set
		if (recordTypesByName.containsKey(objectName)) { 
			Map<String,Schema.RecordTypeInfo> rtMap = recordTypesByName.get(objectName);
			for (String recTypeName : RecordTypeNameSet) {
				if (rtMap.containsKey(recTypeName)) {
					recordTypeIds.add(rtMap.get(recTypeName).getRecordTypeId());
				}
			}
		}
		return recordTypeIds;
	}
	
	/*******************************************************************************************************
	* @description Gives a map of record type Ids from a given object name.
	* @param objectName The name of an Object.
	* @return A Map of Record Type IDs.
	*/
	public static Map<String, Id> GetRecordTypeIdMap(String objectName) {
		Map<String, Id> recordTypeMap = new Map<String, Id>();  
		// make sure we have this object's record types mapped
		if (!recordTypesByName.containsKey(objectName)) 
			fillMapsForObject(objectName);

		// fill the name to id map
		if (recordTypesByName.containsKey(objectName)) { 
			Map<String,Schema.RecordTypeInfo> rtMap = recordTypesByName.get(objectName);
			for (recordTypeInfo rti : rtMap.values()) {
				if (rti.getName() != 'Master')
					recordTypeMap.put(rti.getName(), rti.getRecordTypeId());
			}
		}
		
		return recordTypeMap;
	}

	/*******************************************
	* Gets record type naming suffix from record type name
	Removed from GWBase since static methods cannot be virtual, but
	client would need to be able to override this with their suffixes,
	if we felt we needed to support this functionality.
	
	public static String GetOppNamingSuffix(String RecordTypeName){
		Map<String,String> OpportunitySufix =  new Map<String,String>();

		//add overrides for naming suffixes
		//OpportunitySufix.put('Gift','Gift Suffix');

		String Suffix;
		Suffix = OpportunitySufix.get(RecordTypeName);
		return (Suffix==null) ? RecordTypeName : Suffix;	
	}
	********************************************/
	
	/*******************************************************************************************************
	* @description Gives a list of select options for a Visualforce picklist of record types. 
	* @param objectName The name of an Object.
	* @return A list of Select Options.
	*/
	public static List<SelectOption> getRecordTypesForSelectList(String objectName) {
		
   	 	List<SelectOption> recordTypesOptions = new List<SelectOption>();
		Map<String,Id> availRecordTypes = getRecordTypeIdMap(objectName);
		if (!availRecordTypes.isEmpty()) {
	 		for (string thisRecordType : availRecordTypes.keyset()) {
	 			recordTypesOptions.add(new SelectOption(availRecordTypes.get(thisRecordType), thisRecordType));	
	 		}
		}
   	 	return recordTypesOptions;
    }


	public static string oppRectypeIfExists (string tryFirst) {
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


	// TEST
	static testmethod void testRecTypes() {
		// try bogus values
		Id reallyBogus = GetRecordTypeId('Bogus', 'Bogus');
		System.assert(reallyBogus == null);
		Id bogus = GetRecordTypeId('Opportunity', 'Bogus');
		System.assert(bogus == null);
		bogus = GetRecordTypeId('Contact', 'Bogus');
		System.assert(bogus == null);
		bogus = GetRecordTypeId('Campaign', 'Bogus');
		System.assert(bogus == null);
		
		// try all the functions
		set<Id> oppRtSet = GetRecordTypeIdSet('Opportunity', (new set<string>{'Bogus', 'Master', 'Grant'}));
		Map<String, Id> oppTypeMap = GetRecordTypeIdMap('Opportunity');
		GetRecordTypeName('Opportunity', oppTypeMap.get('Bogus'));
		List<SelectOption> rtOptions = getRecordTypesForSelectList('Opportunity');
		//system.assertEquals('TestName',GetOppNamingSuffix('TestName'));
		
		// check against queried rectypes
		list<recordtype> ort = [select id, name from recordtype where isactive=true and sobjecttype='Opportunity' limit 1];
		if (!ort.isEmpty()) {
			Id rtId = GetRecordTypeId('Opportunity', ort[0].name);
			system.assertEquals(ort[0].id, rtId); 
			String rtName = GetRecordTypeName('Opportunity', ort[0].id);
			system.assertEquals(ort[0].name, rtName); 

			// the sets above should contain something too
			system.assert(oppRtSet.size() > 0);
			system.assert(oppTypeMap.size() > 0);
			system.assert(rtOptions.size() > 0);			
		}	
		
	}
	
	static testMethod void TestRecordTypes() {

		// we are willing to assume that Gift and Grant recordtypes always exist in our base.	
		// note some assertions commented out for GWEngage, since won't apply in all installer orgs
		// we could write some new tests that use describe to get rectypes then test those, but we know this code works
		
		ID idGift = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS);
		ID idGrant = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS);
		// system.Assert(idGift != idGrant);
		
		Set<String> setStr = new Set<String>{ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS};
		Set<Id> setId = GW_RecTypes.GetRecordTypeIdSet('Opportunity', setStr);
		// system.Assert(setId.contains(idGift));
		// system.Assert(setId.contains(idGrant));
		
		Map<String, Id> mapRCId = GW_RecTypes.GetRecordTypeIdMap('Opportunity');
		system.AssertEquals(idGift, mapRCId.get(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS));		
		system.AssertEquals(idGrant, mapRCId.get(ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS));
		
		// system.AssertEquals(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, GW_RecTypes.GetRecordTypeName('Opportunity', idGift));		
		// system.AssertEquals(ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS, GW_RecTypes.GetRecordTypeName('Opportunity', idGrant));		
		
		//system.AssertEquals(rectype1, GW_RecTypes.GetOppNamingSuffix(rectype1));		

		List<SelectOption> listSO = GW_RecTypes.getRecordTypesForSelectList('Opportunity');
		system.Assert(listSO.IsEmpty() == false);		
	}
}