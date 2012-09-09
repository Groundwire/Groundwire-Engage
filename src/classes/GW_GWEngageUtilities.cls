public class GW_GWEngageUtilities {


	
	public class debugLogger {
		// debug log wrapper at request of SF security review
		
		private boolean writeDebugs = false;
		
		public debugLogger() {
			// we want to enable debug logging if we're in the DE org, or an unmanaged environment
			// we want it to stay disabled if it's a subscriber instance w/ installed package
			if (InETPackage) {
				if (InETPackageDevOrg) writeDebugs = true;
			} else {
				writeDebugs = true;
			}
		}
		
		public void debug(string msg) {
			if (writeDebugs) system.debug (LoggingLevel.WARN,msg);
		} 
	}




    /* ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ */
    
    // NAMESPACE PREFIX METHODS
    
    public static string addNSPrefixET (string str, boolean isETField, boolean isNP02Field) {
	     if (str.endsWith('__c') || str.endsWith('__r') ) {
	     	if (str.contains('.')) {
	     		// if we're passed a related field w/ object notation, recurse and do each part of the fieldname separately
	     		// that's because if we may need namespace on both the relationship and the fieldname
	     		// for example in npo02 we need npo02__Household__r.npo02__MembershipEndDate__c
	     		string[] strParts = str.split('\\.');	// need to escape the dot char since this is regex
	     		string newString = '';
	     		for (string s : strParts) {
	     			newString += addNSPrefixET(s,isETField,isNP02Field) + '.';
	     		}
	     		newString = newString.substring(0,newString.length()-1);   //lop off trailing period
	     		return newString;
	     	} else {
				if (isETField) {
					// for fields that are part of ET (like the level fields in contact and campaign)
					// possibilities are:
					// * GWE prefix (ET package installed in NPSP context, or ET package dev instance)
					// * GWBase prefix (GWBase installed, or GWBase package dev instance)
					// * no prefix (unmanaged context, e.g. git clone of GWBase)
					if (InETPackage) {
						return 'gwe__' + str;
					} else {
						return GW_Utilities.StrTokenNSPrefix(str);
					}
				} else {
					// OTOH, if the fields is not part of ET, but rather part of either GWBase or NPSP (like opp rollup fields)
					// possibilities are:
					// * np02 or npe01 prefix (NPSP package installed - which prefix depends on which package the field is in)
					// * GWBase prefix (NPSP not installed, GWBase installed or GWBase package dev instance)
					// * no prefix (as above)
					// note that we don't allow for the case of a developer/unmanaged instance of NPSP, since we (GW) never work in that context
					if (IsNPSPHHInstalled) {
						if (isNP02Field) {
							return 'npo02__' + str;
						} else {
							return 'npe01__' + str;
						}
					} else {
						return GW_Utilities.StrTokenNSPrefix(str);
					}
				}
	     	}
	     } else {
		     return str;
	     }
	     
	}
		    
    public static string addAllNSPrefixET (string str,boolean isETFields, boolean isNP02Fields) {
		string[] fields = str.split(',');
		string newString = '';
		for (string s:fields) {
			s = s.trim();
			newString += addNSPrefixET (s,isETFields,isNP02Fields) + ',';
		}
		newString = newString.substring(0,newString.length()-1);   //lop off trailing period
		return newString;
	}
		    
	private static boolean fCheckedForNPSPHH = false;
	public static boolean IsNPSPHHInstalled {
		get {
			if (!fCheckedForNPSPHH) {
				Schema.SObjectType token = Schema.getGlobalDescribe().get('npo02__Household__c');
				IsNPSPHHInstalled = (token != null);
				fCheckedForNPSPHH = true;
			}
			return IsNPSPHHInstalled;
		}
		set;
	}

	// some older versions of the NPSP package don't have the "Best Gift Year" field
	// to avoid errs, don't assume that this field is available until we check for it	
	private static boolean fCheckedForNPSPBestGiftYear = false;
	public static boolean NPSPHasBestGiftYear {
		get {
			if (!fCheckedForNPSPBestGiftYear) {
				Map<String, Schema.SObjectField> M = Schema.SObjectType.Contact.fields.getMap();
				NPSPHasBestGiftYear = (M.keyset().contains('npo02__best_gift_year__c'));
				fCheckedForNPSPBestGiftYear = true;
			}
			return 	NPSPHasBestGiftYear;		
		}
		set;
	}
		    
	private static boolean fCheckedForGWBase = false;
	public static boolean IsGWBaseInstalled {
		get {
			if (!fCheckedForGWBase) {
				Schema.SObjectType token = Schema.getGlobalDescribe().get('ONEN_Household__c');
				IsGWBaseInstalled = (token != null);
				fCheckedForGWBase = true;
			}
			return IsGWBaseInstalled;
		}
		set;
	}
		
	private static boolean CheckedForETPkg = false;
	public static boolean InETPackageDevOrg = false;
	public static boolean InETPackage {
		get {
			if (!CheckedForETPkg) {
				// first try to look up a ET object using ET pkg namespace - if this works, we're either in the package DE org, or in a subscriber org
				// in the package DE org, we can either use the namespace prefixes or not, but there's no harm in using them
				Schema.SObjectType token = Schema.getGlobalDescribe().get('gwe__EngagementTrackerSettings__c');
				if (token != null) {
					InETPackage = true;
					CheckedForETPkg = true;
					// and we furthermore want to know if we're in the package DE
					// if the describe without the prefix works too, then we know that's where we are
					Schema.SObjectType token2 = Schema.getGlobalDescribe().get('EngagementTrackerSettings__c');
					if (token2 != null) InETPackageDevOrg = true;
					//if (UserInfo.getOrganizationId() == ET_DEV_ORG_ID) InETPackageDevOrg = true;
				} else {
					// if this doesn't work, we are in an unmanaged environemnt, such as a cloned developer instance (git clone)
					// here we don't want the namespace prefixes
					// we used to do a query here, but we don't think we need to anymore
					InETPackage = false;
					CheckedForETPkg = true;
					/*
					string soql = 'SELECT Id,gwe__Engagement_Level__c FROM Contact LIMIT 1';
					try {
						SObject[] recs = database.query(soql);
					} catch (exception e) {
						system.debug ('err: ' + e.getMessage() );
						InETPackage = false;
						CheckedForETPkg = true;
					} finally {
						if (!CheckedForETPkg) {
							InETPackage = true;
							CheckedForETPkg = true;
						}
					}
					*/
				}
			}
			return InETPackage;
		}
		set;
	}


    /* ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ */
    
	// methods called from triggers
	
	public static void BlankETConFields (list<Contact> cons) {
		// called from before insert trigger
		// blank out all ET fields on contact on insert
		// this is done to prevent problems when contact is cloned, since some fields are semi-persistent
		// e.g. peak level won't drop once it's set
		// and as long as we're nulling some it's less confusing for user if we null them all
		string fieldList = addAllNSPrefixET(GW_BATCH_EngagementRollup.CON_FIELDS_ET_EDITABLE,true,false);
		string[] fieldnames = fieldList.split(',');
		for (Contact con : cons) {
			for (string fieldname : fieldnames) {
				con.put(fieldname , null);
			}
		}
	}


    // called from the Contact before trigger
    public static void ContactEngagementLvlOverride() {    
        // when engagement lvl override gets set, apply the default time limit unless user has specified otherwise
        
        Contact[] cons = new Contact[0];
        integer months = (GW_BATCH_EngagementRollup.settings.Override_Default_Duration__c==null) ? GW_BATCH_EngagementRollup.settings.Timeframe_Recent__c.intvalue() : 
        	GW_BATCH_EngagementRollup.settings.Override_Default_Duration__c.intvalue();
        
        date defDate;
        
        for (SObject obj : trigger.new) {
            Contact con = (Contact)obj;
            if (con.Engagement_Level_Override__c!=null) {
                Contact oldCon;
                boolean dateChgd = false;
                boolean lvlChgd = false;
                if (trigger.isUpdate) {
                    oldCon = (Contact)trigger.oldMap.get(con.Id);
                    dateChgd = (con.Engagement_Override_End_Date__c!=oldCon.Engagement_Override_End_Date__c ? true : false );
                    lvlChgd = (con.Engagement_Level_Override__c!=oldCon.Engagement_Level_Override__c ? true : false );
                }
                if ( (trigger.isInsert && con.Engagement_Override_End_Date__c==null) || (trigger.isUpdate && lvlChgd && !dateChgd) ) {
                    cons.add(con);
                }           
            }         
        }
        
        if (cons.size() > 0) {
            // optimization: do date math after first loop
            defDate = system.today().addMonths(months);
            for (Contact con:cons) {
                con.Engagement_Override_End_Date__c = defDate;
            }
        }
    }	



	public static list<Opportunity> insertTestOppsForContactList (list<Contact> Cons, id CampId, string Stage, date Close, double Amt, string rectype, string oppType) {

		// for tests, insert opps & conroles
		// calls the method on UnitTestData to build the opps
		// but also inserts them, and creates conroles as needed if we're not in gwbase or NPSP

		List<Opportunity> opps = ONEN_UnitTestData.OppsForContactList(Cons, CampId, Stage, Close, Amt, rectype, oppType);
		insert opps;

		// if we're not in GWBase or NPSP, then add conroles by hand..
		// tbd this doesn't do households 
		if (! GW_GWEngageUtilities.IsNPSPHHInstalled && ! GW_GWEngageUtilities.IsGWBaseInstalled) {
			list<OpportunityContactRole> conroles = new list<OpportunityContactRole>();
			integer i=0; 
			for (Opportunity opp:opps) {
				OpportunityContactRole conrole = new OpportunityContactRole (
					OpportunityId = opp.Id,
					ContactId = Cons[i].Id,
					IsPrimary = true 
				);
				conroles.add(conrole);
				i++;
			}
			if (conroles.size() > 0) insert conroles;
		}
		
		return opps;
	}

    /* ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ */
    
	// ERROR HANDLING
	
	public class contactValidationErr {
		public Database.SaveResult saveResult;
		public string conName;
		public id conId;
	}
	
	 public static void sendValidationErrEmail (List<contactValidationErr> errList){

		// if we got validation errs while attempting to write to contacts, send an email to notify
		// currently this sends one email per batch 

     	datetime thisDay = system.now();
        
		Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] {'matthew@groundwire.org'});		// tbd get from setting
        // mail.setReplyTo('batch@mycompany.com');
        //mail.setSenderDisplayName('Groundwire Engage');
        mail.setSubject('Groundwire Engage - Contact Validation Error');
		string msg = 'Groundwire Engage encountered one or more errors attempting to save changes to Contact record. ' + 
						'Generally this is due to existing data that does not meet custom validation rules or custom required fields. ' +
						'Please correct any invalid data on the following records:<BR/><BR/>';
		for (contactValidationErr err : errList) {
			string conURL = URL.getSalesforceBaseUrl().toExternalForm() + '/' + err.conId;
			string errDescrip = err.saveResult.getErrors()[0].getMessage();
			msg += 'Contact: <a href="' + conURL + '">' + err.conName + '</a>  Error: ' + errDescrip + '<BR/>';	
		}
		mail.setHTMLBody(msg);

		debugLogger dlog = new debugLogger();
		dlog.debug('validation err email msg: ' + msg);

        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        
        /*
        ore.Name = objid + '-' + thisDay.month() + thisDay.day() + thisDay.hour() + thisDay.minute() + thisDay.second();
        ore.Error_Datetime__c = thisDay;
        ore.Error_Object_Type__c = objecttype;
      
        string recordURL = URL.getSalesforceBaseUrl().toExternalForm() + '/' + objid;
        if (recordURL.startsWith('http:')){
            recordURL = recordURL.replaceFirst('http:', 'https:');
        }
        ore.Error_Record_Link__c = recordURL;
         
        if (s.getErrors()[0].getStatusCode() == system.Statuscode.REQUIRED_FIELD_MISSING){
            ore.Error_Type__c = 'Required Field Missing';
        }
        else if (s.getErrors()[0].getStatusCode() == system.Statuscode.FIELD_CUSTOM_VALIDATION_EXCEPTION){
            ore.Error_Type__c = 'Custom Validation Rule Failed';
        }
        else{
            ore.Error_Type__c = 'Other';
        }
                 
        //trim error message
        if (s.getErrors()[0].getMessage().length() > 255)
            ore.Error_Message__c = s.getErrors()[0].getMessage().substring(0, 254);
        else
            ore.Error_Message__c = s.getErrors()[0].getMessage();
     return ore;
     */
    }
	
}