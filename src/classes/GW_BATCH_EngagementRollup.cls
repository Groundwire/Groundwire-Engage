global virtual class GW_BATCH_EngagementRollup implements Database.Batchable<Sobject>, Schedulable {

/*******************************************************************************************************
* @author Matthew Scholtz
* @date 01/01/2010
* @description This is the primary class for Groundwire Engage.  This class calculates and assigns engagement levels for contacts based on custom settings and
*  Campaign, Opp, and Contact data.  Currently this class only runs during batch, not from a trigger, so in general we recommend scheduling it to run nightly.  
*
* Written by Matthew Scholtz, copyright (c) 2010, 2012 Groundwire
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
*/

    public String Query;
    public boolean isTest; 
    boolean filterTestConsOnly = false;
    
    public map<integer,string> lvlNameMap = new map<integer,string>();
    map<integer,string> lvlNameSettingMap = new map<integer,string> {
            1 => addNSPrefixET('Level_1_Name__c',true,false) , 
            2 => addNSPrefixET('Level_2_Name__c',true,false) , 
            3 => addNSPrefixET('Level_3_Name__c',true,false) , 
            4 => addNSPrefixET('Level_4_Name__c',true,false) , 
            5 => addNSPrefixET('Level_5_Name__c',true,false) , 
            6 => addNSPrefixET('Level_6_Name__c',true,false) , 
            7 => addNSPrefixET('Level_7_Name__c',true,false) , 
            8 => addNSPrefixET('Level_8_Name__c',true,false) };
    integer[] lvlsNoNeedResp = new integer[0];
    map<string,EngagementContactFieldSettings__c> fieldSettingsMap = new map<string,EngagementContactFieldSettings__c>(); 
    map<string,EngagementFrequencySettings__c> freqSettingsMap = new map<string,EngagementFrequencySettings__c>(); 
    public integer monthsRecent;
    public integer monthsMedium;
    private date cutoffDateRecent;
    // private date cutoffDateMedium;  	// deprecated 
    private integer NewMbrLvl;
    private integer RetMbrLvl;
    
    // these fieldlists are static so that static methods called from triggers can access them
    // all of these fields will be blanked out on insert (clone)
    static final string CON_FIELDS_ET_EDITABLE = 'Engagement_Level__c,Engagement_Peak__c,Engagement_Level_Numeric__c,Engagement_Peak_Numeric__c,First_Action_Date_Curr_Level__c,' +
									   			 'Engagement_Level_Override__c,Engagement_Override_End_Date__c,Last_Leadership_Action_Date__c,' + 
									   			 'First_Engagement_Level__c,First_Engagement_Level_Date__c,' + 
									 			 'Last_Engagement_Lvl_Chg_Datestamp__c,Former_Engagement_Level_Numeric__c,Engagement_Level_Change_Log__c,';
	static final string CON_FIELDS_ET_READONLY = 'Engagement_Level_Override_Numeric__c,'; 								    
    
    // these properties will be fetched from the appropriate package (gwbase or npsp) to indicate which opp types are not included in rollups
    set<id> oppRollupRectypesExcluded = new set<id>();
    set<string> oppRollupTypesExcluded = new set<string>(); 
    private boolean fetchedOppRectypes = false;
    private boolean npspAlwaysRollupPrimaryCon = false;
        
    // these are static vars so they can be accessed by the tests before instantiating the class
    static decimal[] donorBreakpoints;
    static map<decimal,double> donorLvlMap;  
    
    // transitory collections
    set<id> conIDs;
    Map<id,engTrackConWrapper> conWrapMap;
    Contact[] convertedCons;
    map<integer,list<Contact>> campConvCandidateMap;
    Contact[] oppConversionCandidateCons;
    Contact[] consToUpd;


    // *** WRAPPER CLASS ***
    global class engTrackConWrapper {
    	
        private id conId,HHid;
        public Contact con;
        public integer CurrLvl = 0;
        public integer PeakLvl = 0;
        public integer OrigLvl = 0;
        public integer OrigPeakLvl = 0;
        public integer FirstLvl, YearAgoLvl;
        public date LastActionDate,FirstDateInLvl,EarliestActivityDateInLvl;
        public boolean isConverting;
        
        // cache of campaign-based data
        public integer LvlFromCampaigns = 0;
        
        // cache of Opp Rollup data
        public integer LvlFromOpps = 0;
        public decimal OppAmountLastNDays_c,OppAmountLastNDaysHH_c,OppsClosedLastNDays_c,OppsClosedLastNDaysHH_c;
		public decimal Best_Gift_Year_Total_c,Best_Gift_Year_TotalHH_c;
        public date LastCloseDate_c,LastCloseDateHH_c;
        public decimal donorTierBreakpoint;
        
        // cache of membership data
        public date MembershipEndDate_c,HouseholdMembershipEndDate_c,LastMembershipDate_c,MembershipJoinDate_c;
        public string LastMembershipOrigin_c;

        //constructor 
        public engTrackConWrapper (id argId) {
            conId = argId;  
        }
        
        public void setLevelTo (integer lvl, date actionDate, boolean removeEarliestActivityDate) {
            if (lvl > CurrLvl) {
            	CurrLvl = lvl;
            	if (removeEarliestActivityDate) {
            		EarliestActivityDateInLvl = null;
            	}
            }
            if (lvl > PeakLvl) PeakLvl = lvl;
            if (actionDate != null && actionDate > LastActionDate) LastActionDate = actionDate;
        }   
    }
    
    /*******************************************************************************************************
	* @description This constructor is needed to allow this class to be schedulable.
	*/
    global GW_BATCH_EngagementRollup() { }
    
    
    /*******************************************************************************************************
	* @description Main constructor.  The arg should be set to true only in a test.
	*/
    global GW_BATCH_EngagementRollup (boolean isTestArg) {
        isTest = isTestArg;
        //DH GW_OppRollups.isTest = isTestArg;
        getSettingParams();
        constructQuery();
    }
    
    /*******************************************************************************************************
	* @description Standard schedulable execute method.  This simply gets the batch started when called from a scheduled job.  Note, this uses a batch size of 50 unless
	*  a different batch size is given in the settings.
	*/    
    global void execute(SchedulableContext SC) {
                 
        integer batchSize = 50;  // default
        if (settings.Batch_Size__c > 0) {
            batchSize = settings.Batch_Size__c.intvalue(); 
        }
         
        GW_BATCH_EngagementRollup ladderBatch = new GW_BATCH_EngagementRollup(false);
        id batchinstanceid = database.executeBatch (ladderBatch, batchSize);  
    }
    
    /*******************************************************************************************************
	* @description Loads an instance of EngagementTrackerSettings__c, creating one with useful defaults
	* if one isn't found.
	*/   
    public static EngagementTrackerSettings__c settings {
        get {
            if (settings == null) {
                settings = EngagementTrackerSettings__c.getValues(UserInfo.getOrganizationId());  
                
                if (settings == null) {
           			// MatthewS felt that if no settings exist, we should give an error to the user,
           			// but DaveH found that this was too easily hit in GWBase instances that will always have this ET, even if not being used.
            		//throw(new MyException('Engagement Tracker requires Engagement Tracker Settings to have been created.  Please create these custom settings.'));
            		settings = new EngagementTrackerSettings__c();
            		// set values code assumes exist
                    // deprecated: settings.Timeframe_Medium__c = 18;
                    settings.Timeframe_Recent__c = 12;
           		}            
            }
            return settings;
        }
        set;
    }

    
    protected void getSettingParams() {
        monthsRecent = settings.Timeframe_Recent__c.intvalue();
        monthsMedium = settings.Timeframe_Medium__c.intvalue();
        fieldSettingsMap = EngagementContactFieldSettings__c.getAll();
        freqSettingsMap = EngagementFrequencySettings__c.getAll();
        if (settings.New_Member_Level__c!=null) NewMbrLvl = settings.New_Member_Level__c.intvalue();
        if (settings.Renewing_Member_Level__c!=null) RetMbrLvl = settings.Renewing_Member_Level__c.intvalue();
        for (integer i=1 ; i<=lvlNameSettingMap.keyset().size() ; i++) {
            string fname = lvlNameSettingMap.get(i);
            object lname = settings.get(fname);
            string lnamestr = (string)lname;
            if (lnamestr!=null) {
                lvlNameMap.put(i,lnamestr);
            }
        }
        if (settings.Levels_Don_t_Require_Responded__c!=null) {
            string[] lvlsNoResp = settings.Levels_Don_t_Require_Responded__c.split(';');
            for(string lvlNoResp:lvlsNoResp) {
                lvlsNoNeedResp.add(integer.valueOf(lvlNoResp));
            }
        }
        if (settings.Testing_Mode__c && !isTest) {
            filterTestConsOnly = True;
        }
    }
    
    
    protected void constructQuery() {
    	// construct the soql batch query
    	
    	// first ET fields
        string querySOQL = 'SELECT Id,Name,Award_Engagement_Levels_for_Org_Giving__c,' + CON_FIELDS_ET_EDITABLE + CON_FIELDS_ET_READONLY;
        querySOQL = addAllNSPrefixET(querySOQL,true,false);
        
        // then fields w/ same name in gwbase & NPSP
        if (IsGWBaseInstalled || IsNPSPHHInstalled) {
	        string querySOQLmore = 'OppAmountLastNDays__c,LastCloseDate__c,LastCloseDateHH__c,OppsClosedLastNDays__c,' +
	        						'OppAmountThisYear__c, OppAmountLastYear__c, OppAmount2YearsAgo__c,Account.Name,Account.OppAmountLastNDays__c,Account.LastCloseDate__c,' +
		        					'MembershipJoinDate__c,MembershipEndDate__c,LastMembershipLevel__c,LastMembershipOrigin__c,LastMembershipDate__c,LastMembershipAmount__c,';
	        querySOQLmore = addAllNSPrefixET(querySOQLmore,false,true);
	        querySOQL += ',' + querySOQLmore; 
        }
        
        if (IsGWBaseInstalled) {
        	// then fields that exist only in gwbase
        	string querySOQLmore = ' Best_Gift_Year__c,Best_Gift_Year_Total__c,OppAmountLastNDaysHH__c, ' + 
        							'ONEN_Household__c,ONEN_Household__r.OppsClosedLastNDays__c,ONEN_Household__r.Best_Gift_Year__c,ONEN_Household__r.Best_Gift_Year_Total__c,' +
									'HouseholdMembershipEndDate__c,';
        	querySOQLmore = addAllNSPrefixET (querySOQLmore,false,true);
        	querySOQL += ',' + querySOQLmore;
        } else if (IsNPSPHHInstalled)	{
        	// and finally fields that only exist in NPSP
			string querySOQLmore = 
				'Household__c,' +
				'Household__r.OppAmountLastNDays__c,' +
				'Household__r.OppAmountThisYear__c, Household__r.OppAmountLastYear__c, Household__r.OppAmount2YearsAgo__c,' +
				'Household__r.OppsClosedLastNDays__c, Household__r.LastMembershipDate__c,';
			if (NPSPHasBestGiftYear) {
				querySOQLmore += 'Best_Gift_Year__c,Best_Gift_Year_Total__c,Household__r.Best_Gift_Year__c,Household__r.Best_Gift_Year_Total__c,';
			}
			querySOQLmore = addAllNSPrefixET (querySOQLmore,false,true);
			querySOQL += ',' + querySOQLmore;
			// and from the other NPSP package...
			querySOQL += ',' + addNSPrefixET ('Account.SYSTEMIsIndividual__c',false,false);
		} 
        
        // include any fields from contact field rules in the query
        if (fieldSettingsMap.size()>0) {
            for (EngagementContactFieldSettings__c s : fieldSettingsMap.values() ) {
            	// but make sure we don't add the same field twice
            	if ( !querySOQL.contains(',' + s.Fieldname__c)) {
                	querySOQL += ',' + s.Fieldname__c ;
            	} 
            }
        }
        // querySOQL = querySOQL.substring(0,querySOQL.length()-1);   //lop off trailing comma
        
        querySOQL += ' FROM Contact';
        
        // this should no longer needed w/ new API that only uses test data by default
        // but for now we need to set our tests as UseAllData b/c otherwise we run into a bug w/ decimals from settings 
        // see https://twitter.com/rich_unger/status/215563857656156161
        // once this bug is fixed, we should be able to get rid of this
        if (isTest) {
            querySOQL += ' WHERE LastName=\'Doppleganger\'';
        } else if (filterTestConsOnly) {
            querySOQL += ' WHERE Title=\'testeng\'';
        }
        
        system.debug (Logginglevel.WARN,'query string: ' + querySOQL);
        Query = querySOQL;      
    }


    /*******************************************************************************************************
	* @description Standard batch start method.   This doesn't do anything interesting.  
	*/    
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator(Query);
    }

    /*******************************************************************************************************
	* @description The main batch execute method.  This is where the majority of the real work is done for the engagement calculation.  This method looks at custom settings, 
	*  and then all related Campaigns and Opps for each contact, to determine the correct score to assign.  It only makes a write to the contact if any of the rollup fields need changing.  
	*/
    global void execute(Database.BatchableContext BC, List<Sobject> SBatch){

        Map<id,Contact> conMap = new Map<id,Contact>();
        conWrapMap = new Map<id,engTrackConWrapper>();
        conIDs = new set<id>();       
        consToUpd = new Contact[0];
          
        cutoffDateRecent = system.today().addMonths(monthsRecent * -1);
        // cutoffDateMedium = system.today().addMonths(monthsMedium * -1);			// deprecated
        
        // cast sobjects to Contacts, and add to wrappers & maps        
        for (sobject s: SBatch) {
            Contact con = (Contact)s;
            conIDs.add(con.Id);
            engTrackConWrapper cw = new engTrackConWrapper(con.Id);
            cw.con = con.clone(true,true);
            if (con.Engagement_Level_Numeric__c != null) cw.OrigLvl = con.Engagement_Level_Numeric__c.intvalue();
            if (con.Engagement_Peak_Numeric__c != null) {
            	cw.PeakLvl = con.Engagement_Peak_Numeric__c.intvalue();
            	cw.OrigPeakLvl = cw.PeakLvl;
            }
            conWrapMap.put (con.Id,cw);
            conMap.put (con.Id,con);
        }
        
        system.debug (Logginglevel.WARN,'conwrapper map before calcs: ' + conWrapMap);
        
        // grab opp rollup data and store data on the contact wrapper object
        if (settings.Include_Opps__c || settings.Include_Membership__c) {
        	CalculateOppData(conWrapMap, conIDs);
        }
        
		// calculate levels based on campaign memberships
		calcCampaignLevels();

		// calculate "repeated action" rules
        calcFrequencyLevels();

        // apply contact-centric level rules & opp-based rules 
    	calcOppAndContactLevels();
        
	    //system.debug (Logginglevel.WARN,'conwrapper map after calcs: ' + conWrapMap);
	    
	    // do any final custom processing implemented via override
	    customFinalLvlAssign (conWrapMap, conIDs);
        
        // figure changes to engagement fields on the contact, and flag conversions
        getContactWrites();
        
        system.debug (LoggingLevel.WARN,'convertedCons: ' + convertedCons);
        system.debug (LoggingLevel.WARN,'convertedCons size: ' + convertedCons.size());
        system.debug (LoggingLevel.WARN,'campConvCandidateMap: ' + campConvCandidateMap);
        system.debug (Logginglevel.WARN,'consToUpd:' + consToUpd);

        if (consToUpd.size() > 0) {
			// identify and write to opps & campaign memberships that qualify as conversions (i.e. caused jump in level)
			calculateConversions();
			system.debug (Logginglevel.WARN,'consToUpd after conversion calcs:' + consToUpd);

			// and finally update our contacts!
            update consToUpd;
        }
    }
  

	private void calcCampaignLevels() {
        // fetch campaign mbrships in recent time period and get max level
        //  (require either that the campaign start date be within the time frame, or that the FirstRespondedDate of the CM is, and is also within Campaign start/end dates)
        // note can't GROUP BY a formula field as of may 2010, so need to group by the text field and manually switch it to numeric
        for (sobject r : 
            [SELECT ContactId, Campaign.Leadership_Level__c campLvl, 
                MAX (Campaign.Engagement_Level_Numeric__c) MaxLevel, COUNT_DISTINCT(Id) countCMs, MAX (Effective_Action_Date__c) LastDate, 
                MIN (Effective_Action_Date__c) FirstDate ,
                GROUPING(ContactId) subtCon, GROUPING(Campaign.Leadership_Level__c) subtLvl 
                FROM CampaignMember 
                WHERE ContactId IN :conIDs
                AND Campaign.Leadership_Level__c!=Null
                AND (HasResponded=True OR Campaign.Engagement_Level_Numeric__c IN :lvlsNoNeedResp)
                AND Effective_Action_Date__c >= :cutoffDateRecent 
                GROUP BY CUBE (ContactId, Campaign.Leadership_Level__c )
                ORDER BY GROUPING(Campaign.Leadership_Level__c) desc , GROUPING(ContactId) 
              ] ) {
                    //system.debug (LoggingLevel.WARN,'agg obj:' + r);
                    engTrackConWrapper cw;
                    if (r.get('subtCon')==0) {
                        Id conid = (id)r.get('ContactId');
                        cw = conWrapMap.get(conid);
                    }
                    if (r.get('subtCon')==0 && r.get('subtLvl')==1 ) {
                        // if this is a contact summary row
                        // temporarily assign this level to the contact (may be raised in later steps)
                        Double lvldbl = (double)r.get('MaxLevel');
                        Integer lvl = lvldbl.intvalue();
                        cw.setLevelTo (lvl,(date)r.get('LastDate'),false);
                        cw.LvlFromCampaigns = lvl;		// cache this so we know what their campaign level was even if raised later
                    } else if (r.get('subtCon')==0 && r.get('subtLvl')==0 ) {
                        // this is a detail row (which should come after all of the con summary rows)
                        if ( (double)r.get('MaxLevel')==cw.CurrLvl ) {
                            cw.EarliestActivityDateInLvl = (date)r.get('FirstDate');
                        }
                    }
        }
        
        // also get the peak lvl (all dates)
        for (sobject r : 
            [SELECT ContactId, 
                MAX (Campaign.Engagement_Level_Numeric__c) MaxLevel, COUNT_DISTINCT(Id) countCMs, MAX (Effective_Action_Date__c) LastDate
                FROM CampaignMember 
                WHERE ContactId IN :conIDs
                AND Campaign.Leadership_Level__c!=Null
                AND (HasResponded=True OR Campaign.Engagement_Level_Numeric__c IN :lvlsNoNeedResp)
                // AND Effective_Action_Date__c >= :cutoffDateRecent 
                GROUP BY ContactId
              ] ) {
                    // and temporarily assign this level to the contact (may be raised in later steps)
                    Id conid = (id)r.get('ContactId');
                    Double lvldbl = (double)r.get('MaxLevel');
                    Integer lvl = lvldbl.intvalue();
                    engTrackConWrapper cw = conWrapMap.get(conid);
                    if (lvl > cw.PeakLvl ) cw.PeakLvl = lvl;
                    if (cw.LastActionDate==null) cw.LastActionDate = (date)r.get('LastDate');
        }
		
	}


	private void calcFrequencyLevels() {
        // now check "repeated action" rules (separate SOQL for each one!)
        for (EngagementFrequencySettings__c fqset : freqSettingsMap.values() ) {
            if (fqset.Campaign_Type__c != null || fqset.Campaign_Sub_Type__c != null || fqset.Campaign_Record_Type__c != null ) {
                string qstr = 'SELECT ContactId,Calendar_Year(Effective_Action_Date__c) yr,COUNT_DISTINCT(Id) CountCMs, ';
                qstr +=         ' GROUPING(ContactId) subtCon  ';
                qstr +=         ' FROM CampaignMember WHERE ContactId IN :conIDs AND Campaign.Leadership_Level__c!=Null ';
                qstr +=         ' AND (HasResponded=True OR Campaign.Engagement_Level_Numeric__c IN :lvlsNoNeedResp) ';
                qstr +=         ' AND Effective_Action_Date__c >= :cutoffDateRecent ';
                // add our namespace prefix to fields we own.
                qstr = addAllNSPrefixET (qstr,true,false);
                
                /* deprecated
                // fields coming from settings we can't assume should be namespace prefixed.
                // qstr +=         ' AND Campaign.' + fqset.Fieldname_1__c + '= \'' + fqset.Field_Value_1__c + '\' ';
                */
                
                // set filters based on campaign types
            	string camptype,campsubtype,camprectype;
                if (fqset.Campaign_Type__c != null) {
                	camptype = fqset.Campaign_Type__c;
                	qstr +=  ' AND Campaign.Type = :camptype ';
                }
                // this one is for GWBase only, will throw an err if set & gwbase not installed
                //  TBD trap this err?
                if (fqset.Campaign_Sub_Type__c != null) {
                	campsubtype = fqset.Campaign_Sub_Type__c;
                	qstr += ' AND ' + addNSPrefixET('Campaign.Campaign_Sub_Type__c',false,false) + ' = :campsubtype ';
                }
                if (fqset.Campaign_Record_Type__c != null) {
                	camprectype = fqset.Campaign_Record_Type__c;
                	qstr += ' AND Campaign.RecordType.Name = :camprectype ';
                }
                
                qstr +=         addAllNSPrefixET(' GROUP BY ROLLUP ( ContactId, Calendar_Year(Effective_Action_Date__c) )' , true, false);
                system.debug (Logginglevel.WARN,'frequency setting for rule: ' + fqset);
                system.debug (Logginglevel.WARN,'querystring for frequency rule: ' + qstr);
                sobject[] results = Database.query(qstr);
                for (sobject row : results) {
                    double count = (double)row.get('CountCMs');
                    if (row.get('subtCon')==0 && row.get('yr')==null && count >= fqset.Number_Of_Actions_Required__c) {
                        // if this is con row, and we meet the frequency criteria, assign lvl to con as appropriate
                        Id conid = (id)row.get('ContactId');
                        engTrackConWrapper cw = conWrapMap.get(conid);
                        cw.setLevelTo(fqset.Level_To_Assign__c.intvalue(), null, false);
                    } else if (row.get('yr')!=null && row.get('subtCon')==0 && count >= fqset.Number_Of_Actions_Required__c) {
                        // if this is a detail row (per con and per yr) then see if constitutes a higher peak
                        Id conid = (id)row.get('ContactId');
                        engTrackConWrapper cw = conWrapMap.get(conid);
                        if (fqset.Level_To_Assign__c > cw.PeakLvl) {
                            cw.PeakLvl = fqset.Level_To_Assign__c.intvalue();
                        }
                    }
                }
            }
        }
		
	}


	private void calcOppAndContactLevels() {
        // now loop back through our contacts and apply contact-centric level rules, opp-based rules & calculate final engagmeent field values
        for (engTrackConWrapper cw : conWrapMap.values() ) {
            Contact con = cw.con;       
        
            // consider con fields
            for (EngagementContactFieldSettings__c fSet : fieldSettingsMap.values()) {
                 boolean qual = false;
                 string fname = fSet.Fieldname__c;
                 object val = con.get(fname);
                 if (fSet.Field_Type__c=='checkbox') {
                     boolean checked = Boolean.valueOf(val);
                     if (checked) qual = true;
                 } else if (fSet.Field_Type__c=='text' && fSet.Field_Value__c != null) {
                    // note this applies to any text equivalent field types: picklist, email, address, etc
                    string valStr = (string)val;
                    if (fSet.Field_Value__c == '*' && valStr!=null && valStr!='') {
                        qual = true;
                    } else if (fSet.Field_Value__c != '*' && fSet.Field_Value__c==valStr) {
                        qual = true;
                    }
                 }
                 
                if (qual==true) {
                    integer fieldlvl = fSet.Level_Value__c.intvalue();
                    cw.setLevelTo(fieldlvl, null, true);
                }   
                 
            }
            
            // chk override
            if (con.Engagement_Level_Override_Numeric__c > 0) {
	            cw.setLevelTo(con.Engagement_Level_Override_Numeric__c.intvalue(), null, true);
            }

            // if including opps, calc levels based on donor rollup fields (assumes rollups are up to date)
            if (settings.Include_Opps__c) {
                // first get settings for donor level tiers
                fetchDonorBreakpoints();
                if (donorBreakpoints.size() > 0) {
                    //system.debug(Logginglevel.WARN, 'donorBreakpoints: ' + donorBreakpoints);
                    
                    // now use opp rollup fields to figure the donor-derived level
                    decimal recentGiftTtl = cw.OppAmountLastNDays_c; 
                    decimal recentGiftTtlHH = cw.OppAmountLastNDaysHH_c;
                    boolean useHHTotals = settings.Householded_Donor_Levels__c;
                    decimal bestYrTotal;
                    date lastCloseDate;
                    if (useHHTotals && cw.HHid != null) {
                    	// use HH totals if settings says so
                    	recentGiftTtl = recentGiftTtlHH;
                    	bestYrTotal = cw.Best_Gift_Year_TotalHH_c;
                    	lastCloseDate = cw.LastCloseDateHH_c;
                    } else {
                    	bestYrTotal = cw.Best_Gift_Year_Total_c;
                    	lastCloseDate = cw.LastCloseDate_c;
                    }
                    
                    // if indicated, give credit for org's gifts too
                    if (con.Award_Engagement_Levels_for_Org_Giving__c == true) {
                    	// but don't do it if we're in NPSP and this is a 1-to-1 or individual acct, since that will double count
                    	// also don't do it if we're in NPSP and they have the "always rollup to primary contact" option selected in settings
                    	// so first we have to fetch opp rollup settings if we're in NPSP
						boolean skipIt = false;
                    	if (IsNPSPHHInstalled) {
                    		setGiftRectypeVars();
                    		Account acct = con.Account;	// gotta put account in a separate var cause can't do .get() on a parent field
                    		boolean bucket = (boolean) acct.get(addNSPrefixET('SYSTEMIsIndividual__c',false,false));
	                    	if (bucket || npspAlwaysRollupPrimaryCon) {
	                    		skipIt = true;
	                    	}
                    	}
                    	if (!skipIt) {
		                    	Account acct = con.Account;
		                    	decimal acctGiftTtl = (decimal) acct.get(addNSPrefixET('OppAmountLastNDays__c',false,true));
		                    	date acctLastCloseDate = (date) acct.get(addNSPrefixET('LastCloseDate__c',false,true));
		                    	system.debug(LoggingLevel.WARN,'recentGiftTtl:' + recentGiftTtl + '   acctGiftTtl:' + acctGiftTtl);
		                    	recentGiftTtl += acctGiftTtl;
		                    	if (acctLastCloseDate > lastCloseDate) lastCloseDate = acctLastCloseDate;
                    	}
                    }		
                    
                    double lvlRecent; 
                    double lvlPeak;
                    for (integer i=0;i<donorBreakpoints.size();i++) {
                        decimal brkpt = donorBreakpoints[i];
                        integer lvl = donorLvlMap.get(brkpt).intvalue();
                        if (recentGiftTtl >= brkpt) {
                        	cw.LvlFromOpps = lvl;	// we want to know which level our opps would have earned us, even if we already have that lvl
                        	cw.donorTierBreakpoint = brkpt;
                        }
                        if (recentGiftTtl >= brkpt && lvl > cw.CurrLvl) {
                        	cw.setLevelTo(lvl, lastCloseDate, false);
                            decimal oppsCount = (useHHTotals) ? cw.OppsClosedLastNDaysHH_c : cw.OppsClosedLastNDays_c;
                            if (oppsCount == 1) {
                                cw.EarliestActivityDateInLvl = (useHHTotals) ? cw.LastCloseDateHH_c : cw.LastCloseDate_c;     // if only 1 gift, last is also the first
                            } else {
                                // TBD we could add this con to a list, and then query for the actual first date??
                                cw.EarliestActivityDateInLvl = cutoffDateRecent;  // b/c level is awarded for entire year, not one gift
                            }
                            

                        // assign lastaction date even if we don't give the level, as long as they already had a date (i.e. level not due to override or chkbox)
                        //  and this date is more recent
                        } else if (bestYrTotal > 0 && lastCloseDate > cw.LastActionDate && cw.LastActionDate!=null) {
                            cw.LastActionDate = cw.LastCloseDate_c;
                        }
                        // for peak level, look at best year calcs even if we didn't give the curr lvl
                        if ( lvl > cw.PeakLvl && bestYrTotal >= brkpt ) {
                            cw.PeakLvl = lvl;
                        }
                    }
                }
            }
           
            // now figure membership
            if (settings.Include_Membership__c && (cw.MembershipEndDate_c!=null || cw.HouseholdMembershipEndDate_c!=null) && RetMbrLvl!=null && NewMbrLvl!=null) {
                integer mbrlvl;
                if (cw.LastMembershipOrigin_c=='Renewal' || cw.LastMembershipDate_c > cw.MembershipJoinDate_c) {
                    mbrlvl = RetMbrLvl;
                } else {
                    mbrlvl = NewMbrLvl;
                }
                if (cw.LastMembershipDate_c >= cutoffDateRecent) {
                	cw.setLevelTo(mbrLvl, null, false);
                }
            }   
        }
		
	}


	private void getContactWrites() {
	    // write chgs to contacts, but only if something actually changed
	    
        // collections for conversion analytics
        convertedCons = new Contact[0]; 
        campConvCandidateMap = new map<integer,list<Contact>>();
        oppConversionCandidateCons = new Contact[0];
	    
        for (engTrackConWrapper cw : conWrapMap.values() ) {
            Contact con = cw.con;               
            string lvlStr = lvlNameMap.get(cw.CurrLvl);
            string peakStr = lvlNameMap.get(cw.PeakLvl);

			// update our year ago level from the log of changes
			updateYearAgoLevelFromLog(cw);

            if (cw.CurrLvl != cw.OrigLvl || cw.PeakLvl != con.Engagement_Peak_Numeric__c || lvlStr!=con.Engagement_Level__c || 
                peakStr!=con.Engagement_Peak__c || cw.LastActionDate!=con.Last_Leadership_Action_Date__c 
                // temp disabled for security review	|| cw.YearAgoLvl != con.Engagement_Level_One_Year_Ago__c 
                ) 
                {
	                // first, if curr level changed, log the date and former level in contact fields (for use in calculating conversion later, etc.)
	                // and add to our JSON changelog
                    if (cw.CurrLvl != cw.OrigLvl) {
                    	con.Last_Engagement_Lvl_Chg_Datestamp__c = system.now();
                    	con.Former_Engagement_Level_Numeric__c = con.Engagement_Level_Numeric__c;
                    	con.First_Action_Date_Curr_Level__c = system.today();
                    	updateLevelChangeLog(cw);
                    	
                    	// capture first level if that's what this is
                    	if (cw.OrigLvl==0 && cw.OrigPeakLvl==0) {
                    		con.First_Engagement_Level__c = cw.CurrLvl;
                    		cw.FirstLvl = cw.CurrLvl;
                    		con.First_Engagement_Level_Date__c = system.today();
                    	}
                    	
                    	// also flag as conversion if level is rising
                    	if (cw.CurrLvl > cw.OrigLvl) {
                    		cw.isConverting = true;
                    		convertedCons.add(con);
                    		
                    		// and flag those whose conversions are possibly due to campaigns, opps, or both
                    		// if (cw.CurrLvl == cw.LvlFromCampaigns) campConversionCandidateCons.add(con);
                    		if (cw.CurrLvl == cw.LvlFromCampaigns) {
                    			// first get the right list from the map, or create if necessary, and add this con to it
                    			Contact[] conList;
                    			if (campConvCandidateMap.get(cw.CurrLvl) == null ) {
                    				conList = new Contact[0];
                    			} else {
                    				conList = campConvCandidateMap.get(cw.CurrLvl);
                    			}
                    			conList.add (con);
                    			// then put it back in the map
                    			campConvCandidateMap.put(cw.CurrLvl,conList);
                    		}
                    		if (cw.CurrLvl == cw.LvlFromOpps) {
                    			oppConversionCandidateCons.add (con);
                    		}
                    	}
                    }
                    
                    // then update other metrics
                    con.Engagement_Level_Numeric__c = cw.CurrLvl;
                    con.Engagement_Peak_Numeric__c = cw.PeakLvl;
                    con.Engagement_Level__c = lvlStr; 
                    con.Engagement_Peak__c = peakStr; 
                    con.Last_Leadership_Action_Date__c = cw.lastActionDate;
                    // temp disabled for security review	con.Engagement_Level_One_Year_Ago__c = cw.YearAgoLvl;
                    
                    consToUpd.add(con);
                }
        }
		
	}


	public class DateIntegerPair {
		public date d;
		public integer i;
		
		public DateIntegerPair(date d,integer i) {
			this.d = d;
			this.i = i;
		}
	}

	private void updateLevelChangeLog(engTrackConWrapper cw) {
		
		// first deserialize our JSON to a list of objects
		integer len = 0;
		list<DateIntegerPair> changes;
		if (cw.con.Engagement_Level_Change_Log__c != null) {
			changes = (list<DateIntegerPair>) JSON.deserialize(cw.con.Engagement_Level_Change_Log__c, list<DateIntegerPair>.class);
			len = cw.con.Engagement_Level_Change_Log__c.length();
		} else {
			changes = new list<DateIntegerPair>();
		}
		
		// add our new change to the log 
		// TBD take out any older than 13 months, and/or police the total char length
		// TBD replace any existing entries w/ same date
		DateIntegerPair thisChg = new DateIntegerPair(system.today(),cw.CurrLvl);
		changes.add(thisChg);
		cw.con.Engagement_Level_Change_Log__c = JSON.serialize (changes);
	}
	
	private void updateYearAgoLevelFromLog (engTrackConWrapper cw) {
		// date loopDate;
		date yrAgo = system.today().addYears(-1);
		integer lvl;
		if (cw.con.Engagement_Level_Change_Log__c != null) {
			list<DateIntegerPair> changes = (list<DateIntegerPair>) JSON.deserialize(cw.con.Engagement_Level_Change_Log__c, list<DateIntegerPair>.class);
			// loop through until we pass our target date; the last chg before the target is the one we want
			for (DateIntegerPair chg : changes) {
				if (chg.d < yrAgo) {
					// loopDate = chg.d;
					lvl = chg.i;
				} else {
					break;
				}
			}
			cw.YearAgoLvl = lvl;
		} else {
			cw.YearAgoLvl = null;
		}
	}

	private void calculateConversions() {
			// before updating contacts, figure campaign & opp conversions
			// need to do this first, b/c relies on the date of last eng change on Contact
			// first find all CM's that are candidates
			// meaning they belong to one of our candidate cons, have the right engagement level, and dates are right
			// the last criterion (Conversion_Candidate__c) is a formula field based on what the contact's level was when campaign membership was inserted, and dates
			// we will do a series of queries, one for each engagement level that has candidates, so max of 8 queries total here
			map<Id,CampaignMember> firstCandidateCMmap = new map<Id,CampaignMember>();
			map<Id,OpportunityContactRole> firstCandidateOppMap = new map<Id,OpportunityContactRole>();
			for (integer Lvl : campConvCandidateMap.keyset()) {
				Contact[] conCandidates = campConvCandidateMap.get(Lvl);
				CampaignMember[] cmCandidates = [SELECT Id,ContactId,CampaignID,Status,Engagement_Conversion__c,Engagement_Conversion_To_Level__c,
												Engagement_Conversion_From_Level__c,Effective_Action_Date__c 
												FROM CampaignMember
												WHERE ContactId IN :conCandidates
													AND ((HasResponded = true OR Campaign.Engagement_Level_Numeric__c IN :lvlsNoNeedResp) AND (New_Since_Last_Engagement_Chg__c = 'True' OR Responded_Since_Last_Engagement_Chg__c = 'True'))
													AND Campaign.Engagement_Level_Numeric__c = :Lvl AND Effective_Action_Date__c >= :cutoffDateRecent
													AND Conversion_Candidate__c = 'True'
													ORDER BY Effective_Action_Date__c];
				system.debug (LoggingLevel.WARN,'cmCandidates for lvl ' + Lvl + ':' + cmCandidates);
													
				// loop thru the results and find the earliest-dated CM for each contact (easy since pre-ordered)
				for (CampaignMember cm : cmCandidates) {
					if (firstCandidateCMmap.get(cm.ContactId) == null) {
						firstCandidateCMmap.put(cm.ContactId,cm);
					}
				}
			}
			
			// now find candidate opps for each flagged contact
			// need to fetch all opps in the timeframe, since the level is assigned based on total
			
			// first we fetch (from GWBase or NPSP) lists of rectypes and type values that are being excluded in the opp rollups
			// since we need to apply the same filters here 
			setGiftRectypeVars();
					
			OpportunityContactRole[] oppCandidates = [SELECT OpportunityId,ContactId,Opportunity.Name,Opportunity.Amount,Opportunity.StageName,Opportunity.CloseDate  
											FROM OpportunityContactRole
											WHERE ContactId IN :oppConversionCandidateCons AND IsPrimary = True 
											AND Opportunity.CloseDate >= :cutoffDateRecent AND Opportunity.IsWon = True
											AND Opportunity.RecordTypeId NOT IN :oppRollupRectypesExcluded
											AND Opportunity.Type NOT IN :oppRollupTypesExcluded
											ORDER BY ContactId, Opportunity.CloseDate];

			// now loop thru the opps and find which opp pushed each contact over the threshhold for their current opp level
			id conIdCursor;
			decimal amtTotal;
			decimal breakpoint;
			boolean foundCandidate = false;
			for (OpportunityContactRole cr : oppCandidates) {
				if (conIdCursor != cr.ContactId) {
					conIdCursor = cr.ContactId;
					amtTotal = 0;
					breakpoint = conWrapMap.get(cr.ContactId).donorTierBreakpoint;
					foundCandidate = false;
				}
				if (!foundCandidate) {
					amtTotal += cr.Opportunity.Amount;
					if (amtTotal >= breakpoint) {
						firstCandidateOppMap.put (cr.ContactId, cr);
						foundCandidate = true;
					}
				}
			}
											
			
			// now loop thru each con candidate, and find whether opp or cm is earlier, and make that the conversion
			CampaignMember[] cmConversions = new CampaignMember[0]; 
			OpportunityContactRole[] oppConversions = new OpportunityContactRole[0]; 
			for (Contact con : convertedCons) {
				if (firstCandidateCMmap.get(con.Id) == null && firstCandidateOppMap.get(con.Id) != null) {
					oppConversions.add (firstCandidateOppMap.get(con.Id));
				} else if (firstCandidateCMmap.get(con.Id) != null && firstCandidateOppMap.get(con.Id) == null) {
					cmConversions.add (firstCandidateCMmap.get(con.Id));
				} else if (firstCandidateCMmap.get(con.Id) != null && firstCandidateOppMap.get(con.Id) != null) {
					// campaign wins the tie..
					CampaignMember cm = firstCandidateCMmap.get(con.Id);
					Opportunity opp = firstCandidateOppMap.get(con.Id).Opportunity;
					if (cm.Effective_Action_Date__c <= opp.CloseDate) {
						cmConversions.add(cm);
					} else {
						oppConversions.add(firstCandidateOppMap.get(con.Id));
					}
				}
			}
			system.debug (LoggingLevel.WARN,'cmConversions list before updates: ' + cmConversions);
			
			
			// now loop through our conversion CM's & update
			if (cmConversions.size() > 0) {
				for (CampaignMember cm : cmConversions) {
					cm.Engagement_Conversion__c = true;
					engTrackConWrapper cw = conWrapMap.get(cm.ContactId);
					cm.Engagement_Conversion_From_Level__c = cw.OrigLvl;
					cm.Engagement_Conversion_To_Level__c = cw.CurrLvl;
					cm.Engagement_Conversion_Type__c = (cw.OrigPeakLvl < cw.CurrLvl) ? 'New' : 'Returning';
					if (cw.OrigPeakLvl == 0) cm.Engagement_List_Growth__c = true;
					// also back-date the "first day in level" on the contact (and first level date, if this is a list growth situation)
					cw.EarliestActivityDateInLvl = cm.Effective_Action_Date__c;
                    cw.con.First_Action_Date_Curr_Level__c = cm.Effective_Action_Date__c;
                    if (cw.FirstLvl > 0) {
                    	cw.con.First_Engagement_Level_Date__c = cm.Effective_Action_Date__c;
                    }
				}
				update cmConversions;
				system.debug (LoggingLevel.WARN,'cmConversions list after updates: ' + cmConversions);
			}			
			
			// do the same w/ opp conversions
			if (oppConversions.size() > 0) {
				Opportunity[] oppConversionsUpd = new Opportunity[0];
				for (OpportunityContactRole cr : oppConversions) {
					Opportunity opp = cr.Opportunity;
					opp.Engagement_Conversion__c = true;
					engTrackConWrapper cw = conWrapMap.get(cr.ContactId);
					opp.Engagement_Conversion_From_Level__c = cw.OrigLvl;
					opp.Engagement_Conversion_To_Level__c = cw.CurrLvl;
					opp.Engagement_Conversion_Type__c = (cw.OrigPeakLvl < cw.CurrLvl) ? 'New' : 'Returning';
					if (cw.OrigPeakLvl == 0) opp.Engagement_List_Growth__c = true;
					oppConversionsUpd.add (opp);
					// also back-date the "first day in level" on the contact
					cw.EarliestActivityDateInLvl = opp.CloseDate;
					cw.con.First_Action_Date_Curr_Level__c = opp.CloseDate;
                    if (cw.FirstLvl > 0) {
                    	cw.con.First_Engagement_Level_Date__c = opp.CloseDate;
                    }
				}
				update oppConversionsUpd;
				system.debug (LoggingLevel.WARN,'oppConversionsUpd list after updates: ' + oppConversionsUpd);				
			}			
		
	}
	
  
  	private void setGiftRectypeVars() {

		// get lists of rectypes excluded from opp rollups, but only if we haven't already done so 

  		Id orgid = UserInfo.getOrganizationId();
  		string rectypesExcludeSetting;
  		string typesExcludeSetting;
  		
  		if (!fetchedOppRectypes) {
	  		if (IsGWBaseInstalled) {
	  			string soql = 'SELECT SetupOwnerId,Id,GWBase__Excluded_Contact_Opp_Types__c,GWBase__Excluded_Contact_Opp_Rectypes__c FROM GWBase__OppRollupSettings__c ';
	  			soql += 		'WHERE SetupOwnerId =: orgid';
	  			sobject[] settingRecs = Database.query (soql);
	  			if (settingRecs != null) {
		  			rectypesExcludeSetting = (string) settingRecs[0].get('GWBase__Excluded_Contact_Opp_Rectypes__c');
		  			typesExcludeSetting = (string) settingRecs[0].get('GWBase__Excluded_Contact_Opp_Types__c');
	  			}
	  			fetchedOppRectypes = true;
	  		} else if (IsNPSPHHInstalled) {
	  			string soql = 'SELECT SetupOwnerId,Id,npo02__Excluded_Contact_Opp_Types__c,npo02__Excluded_Contact_Opp_Rectypes__c,npo02__Always_Rollup_to_Primary_Contact__c FROM npo02__Households_Settings__c ';
	  			soql += 		'WHERE SetupOwnerId =: orgid';
	  			sobject[] settingRecs = Database.query (soql);
	  			if (settingRecs != null) {
		  			rectypesExcludeSetting = (string) settingRecs[0].get('npo02__Excluded_Contact_Opp_Rectypes__c');
		  			typesExcludeSetting = (string) settingRecs[0].get('npo02__Excluded_Contact_Opp_Types__c');
		  			// while we're at it, for NPSP also capture the notorious 'always rollup' setting
		  			npspAlwaysRollupPrimaryCon = (boolean) settingRecs[0].get('npo02__Always_Rollup_to_Primary_Contact__c');
	  			}
	  			fetchedOppRectypes = true;
	  		} else {
	  			// if neither package installed, for now do nothing.. might want to throw an err instead
	  		}
	  		
	  		if (rectypesExcludeSetting != null) {
	            set<string> rtNamesToExclude = new set<string>(rectypesExcludeSetting.split(';'));
	            oppRollupRectypesExcluded = GW_RecTypes.GetRecordTypeIdSet('Opportunity', rtNamesToExclude);  			
	  		}
	  		if (typesExcludeSetting != null) {
	  			oppRollupTypesExcluded = new set<string>(typesExcludeSetting.split(';'));
	  		}
  		}
  	}
  

    /*******************************************************************************************************
	* @description Go through the contacts' opportunities, and cache a bunch of donor and membership related
	* data.
	*/      
	private	void CalculateOppData(Map<id,engTrackConWrapper> conWrapMap, set<id> conIDs) {
		
		for (engTrackConWrapper cw : conWrapMap.values()) {
			Contact con = cw.con;
			sObject hh;
			
			// these fields have the same name in gwbase & npsp, just have to mind the prefix  
	        cw.OppAmountLastNDays_c = (decimal)con.get( addNSPrefixET('OppAmountLastNDays__c',false,true) );		        
	        cw.LastCloseDate_c = (date)con.get( addNSPrefixET('LastCloseDate__c',false,true) );
	        cw.OppsClosedLastNDays_c = (decimal)con.get( addNSPrefixET('OppsClosedLastNDays__c',false,true) );
	        cw.LastCloseDateHH_c = (date)con.get( addNSPrefixET('LastCloseDateHH__c',false,true) );
	        cw.MembershipEndDate_c = (date)con.get( addNSPrefixET('MembershipEndDate__c',false,true) );
	        cw.LastMembershipOrigin_c = (string)con.get( addNSPrefixET('LastMembershipOrigin__c',false,true) );
	        cw.LastMembershipDate_c = (date)con.get( addNSPrefixET('LastMembershipDate__c',false,true) );
	        cw.MembershipJoinDate_c = (date)con.get( addNSPrefixET('MembershipJoinDate__c',false,true) );
	        
	        if (IsGWBaseInstalled) {
	        	// these fields are only in gwbase (for now) or have different names
		        cw.OppAmountLastNDaysHH_c = (decimal)con.get( addNSPrefixET('OppAmountLastNDaysHH__c',false,true) );
		        cw.HouseholdMembershipEndDate_c = (date)con.get( addNSPrefixET('HouseholdMembershipEndDate__c',false,true) );
		        cw.HHid = (id) con.get(addNSPrefixET('ONEN_Household__c',false,true) );
				hh = con.getSObject(addNSPrefixET('ONEN_Household__r',false,true) );  
				if (hh != null) {
		        	cw.OppsClosedLastNDaysHH_c = (decimal)hh.get(addNSPrefixET('OppsClosedLastNDays__c',false,true));
				}
	        } else if (IsNPSPHHInstalled)	{
				cw.HHid = (id) con.get(addNSPrefixET('Household__c',false,true) );
				hh = con.getSObject('npo02__Household__r');  
				if (hh != null) {
					// npsp doesn't roll up some HH metrics to the contact
			        cw.OppAmountLastNDaysHH_c = (decimal)hh.get('npo02__OppAmountLastNDays__c');		        
			        cw.OppsClosedLastNDaysHH_c = (decimal)hh.get('npo02__OppsClosedLastNDays__c');
			        cw.HouseholdMembershipEndDate_c = (date)hh.get('npo02__LastMembershipDate__c');
				}	        	
	        }
	        
	        // get best gift year calcs if we're in gwbase or in a NPSP version that has them
	        if (IsGWBaseInstalled || NPSPHasBestGiftYear) {
	        	cw.Best_Gift_Year_Total_c = (decimal)con.get( addNSPrefixET('Best_Gift_Year_Total__c',false,true) );
	        	if (hh != null) {
	        		cw.Best_Gift_Year_TotalHH_c = (decimal)hh.get(addNSPrefixET('Best_Gift_Year_Total__c',false,true));
	        	}
	        } else if (IsNPSPHHInstalled && !NPSPHasBestGiftYear) {
		        // estimate this if we don't have the best gift year fields
		        decimal d1 = (decimal)con.get('npo02__OppAmountThisYear__c');
		        decimal d2 = (decimal)con.get('npo02__OppAmountLastYear__c');
		        decimal d3 = (decimal)con.get('npo02__OppAmount2YearsAgo__c');
		        cw.Best_Gift_Year_Total_c = math.max(d1 == null ? 0 : d1,
		        		math.max(d2 == null ? 0 : d2,
		        			d3 == null ? 0 : d3));	 
		        d1 = (decimal)hh.get('npo02__OppAmountThisYear__c');
		        d2 = (decimal)hh.get('npo02__OppAmountLastYear__c');
		        d3 = (decimal)hh.get('npo02__OppAmount2YearsAgo__c');
		        cw.Best_Gift_Year_TotalHH_c = math.max(d1 == null ? 0 : d1,
		        		math.max(d2 == null ? 0 : d2,
		        			d3 == null ? 0 : d3));       	
	        }
		}
	} 


	static void fetchDonorBreakpoints() {
        if (donorBreakpoints == null || donorLvlMap == null) {
	        donorBreakpoints = new list<decimal>();
	        donorLvlMap = new map<decimal,double>();  
	        List<Engagement_Donor_Level_Settings__c> donorLvlDefs = Engagement_Donor_Level_Settings__c.getall().values();
	        if (donorLvlDefs.size() > 0) {
	            for (Engagement_Donor_Level_Settings__c s : donorLvlDefs ) {
	                donorBreakpoints.add (s.Lower_Limit__c);
	                donorLvlMap.put (s.Lower_Limit__c,s.Level__c);
	            }
	            donorBreakpoints.sort();
	        }
        }
	}
    
    /*******************************************************************************************************
	* @description an empty hook method intended for overriding - this will get called once all of the regular logic has been run and all contacts in the batch have been asssigned
	*  an engagement level (in memory only, not yet written to database)
	*  This gives developers an opportunity to tweak the levels according to custom logic before those levels get written
	*  In order to utilize this, extend the engagementRollup class, override this method, and then schedule the subclass to run, and disable any schedules using the superclass
	*/      
    global virtual void customFinalLvlAssign (Map<id,engTrackConWrapper> conWrapMap, set<id> conIDs){
        
    }
    

    

    /*******************************************************************************************************
	* @description The standard batch finish method.  Once this batch is done, run the campaign-based batch process (for response rates, etc.)
	*/      
    global void finish(Database.BatchableContext BC){
		// once this batch is done, run the campaign-based batch process (for response rates, etc.)
        //Schedule the batch apex to run in 30 seconds
        if (! Test.isRunningTest()) {
	        Datetime sysTime = System.Now().addSeconds(30);
	        String chron_exp = '' + sysTime.second() + ' ' + sysTime.minute() + ' ' + sysTime.hour() + ' ' + sysTime.day() + ' ' + sysTime.month() + ' ? ' + sysTime.year();
	        GW_BATCH_CampaignEngagementRollup batch = new GW_BATCH_CampaignEngagementRollup();  
	        System.schedule('GW Engage Campaign Rollup ' + sysTime.getTime(), chron_exp, batch);               
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
	public static boolean InETPackage {
		get {
			if (!CheckedForETPkg) {
				// first try to look up a ET object using ET pkg namespace - this should only work in an installed (i.e. client) instance
				Schema.SObjectType token = Schema.getGlobalDescribe().get('gwe__EngagementTrackerSettings__c');
				if (token != null) {
					InETPackage = true;
					CheckedForETPkg = true;
				} else {
					// if this doesn't work, we are either in the ET dev instance itself, or in an unmanaged developer instance (git clone)
					// the former still needs to include the prefixes, while the latter needs to not include them
					// in order to tell the difference, try a dynamic query w/ the prefix and see if we get an err
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
				}
			}
			return InETPackage;
		}
		set;
	}
	
	
	public static void BlankETConFields (list<Contact> cons) {
		// called from before insert trigger
		// blank out all ET fields on contact on insert
		// this is done to prevent problems when contact is cloned, since some fields are semi-persistent
		// e.g. peak level won't drop once it's set
		// and as long as we're nulling some it's less confusing for user if we null them all
		string fieldList = addAllNSPrefixET(CON_FIELDS_ET_EDITABLE,true,false);
		string[] fieldnames = fieldList.split(',');
		for (Contact con : cons) {
			for (string fieldname : fieldnames) {
				con.put(fieldname , null);
			}
		}
	}
	
	
    /* ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ */

    


    // called from the Contact before trigger
    public static void ContactEngagementLvlOverride() {    
        // when engagement lvl override gets set, apply the default time limit unless user has specified otherwise
        // can't do this w/ workflow due to limitations in date arithmetic
        
        Contact[] cons = new Contact[0];
        integer months = (settings.Override_Default_Duration__c==null) ? settings.Timeframe_Recent__c.intvalue() : 
        	settings.Override_Default_Duration__c.intvalue();
        
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
    

    // *** TESTS **********************************************************************
    
    // test constants
    static integer SMALLGIFTLVL,MAJORGIFTLVL,MONTHS_RECENT,MONTHS_MEDIUM,NEWMBRLVL,RENMBRLVL,OVERDEFDUR;
    static decimal MAJGIFTAMT;
    static string INCOPPTYPES,MBROPPTYPES;
    static boolean INCOPPS,INCMBR;
    
    
    public static void setSettingsForTests(string txtfield1, string txtfield1FV, double txtfield1lvl) {

        settings.Include_Opps__c = IsNPSPHHInstalled || IsGWBaseInstalled; 
        settings.Timeframe_Recent__c = 12;
        settings.Timeframe_Medium__c = 12;
        settings.Include_Membership__c = IsNPSPHHInstalled || IsGWBaseInstalled;
        settings.New_Member_Level__c = 3;
        settings.Renewing_Member_Level__c = 4;
        settings.Override_Default_Duration__c = 12;
        settings.Batch_Size__c = 25;
        settings.Level_1_Name__c = '1 - lvl one';
        settings.Level_2_Name__c = '2 - lvl two';
        settings.Level_3_Name__c = '3 - lvl three';
        settings.Level_4_Name__c = '4 - lvl four';
        settings.Level_5_Name__c = '5 - lvl five';
        settings.Level_6_Name__c = '6 - lvl six';
        settings.Householded_Donor_Levels__c = settings.Include_Opps__c; 
        upsert settings;
        
        // clear out list settings
        ONEN_UnitTestData.DeleteListCustomSettingRecs ('EngagementContactFieldSettings__c');
        ONEN_UnitTestData.DeleteListCustomSettingRecs ('EngagementFrequencySettings__c');
        ONEN_UnitTestData.DeleteListCustomSettingRecs ('Engagement_Donor_Level_Settings__c');
        ONEN_UnitTestData.DeleteListCustomSettingRecs ('EngagementCampaignSettings__c');        
        
        // now add list settings back in
            // first fields

        EngagementContactFieldSettings__c fset = new EngagementContactFieldSettings__c (
            Name = 'foo',
            Fieldname__c = txtfield1,
            Field_Type__c = 'Text',
            Field_Value__c = txtfield1FV,
            Level_Value__c = txtfield1lvl
        );
        EngagementContactFieldSettings__c fset2 = new EngagementContactFieldSettings__c (
            Name = 'bar',
            Fieldname__c = 'Email',
            Field_Type__c = 'Text',
            Field_Value__c = '*',
            Level_Value__c = 1
        );
        // put in another rule on the same field to make sure that's not a problem
        EngagementContactFieldSettings__c fset3 = new EngagementContactFieldSettings__c (
            Name = 'baz',
            Fieldname__c = 'Email',
            Field_Type__c = 'Text',
            Field_Value__c = 'algore@internet.com',
            Level_Value__c = 2
        );
        insert new EngagementContactFieldSettings__c[] {fset,fset2,fset3};
        
        // next frequency rules
        EngagementFrequencySettings__c fqset = new EngagementFrequencySettings__c (
            Name = 'foo',
            Level_Required__c = 2,
            Level_To_Assign__c = 3,
            Number_of_Actions_Required__c = 3,
            Campaign_Type__c = 'Online Action'
        );
        insert fqset;
        
        // next donor tiers
        Engagement_Donor_Level_Settings__c dset1 = new Engagement_Donor_Level_Settings__c (
            Name = 'foo',
            Lower_Limit__c = 1.0,
            Level__c = 2
        );
        Engagement_Donor_Level_Settings__c dset2 = new Engagement_Donor_Level_Settings__c (
            Name = 'foo2',
            Lower_Limit__c = 100.0,
            Level__c = 3
        );
        Engagement_Donor_Level_Settings__c dset3 = new Engagement_Donor_Level_Settings__c (
            Name = 'foo3',
            Lower_Limit__c = 1000.0,
            Level__c = 4
        );
        Engagement_Donor_Level_Settings__c[] dsets = new Engagement_Donor_Level_Settings__c[] {dset1,dset2,dset3};
        insert dsets;
        
        // next Campaign defaults
        EngagementCampaignSettings__c cs1 = new EngagementCampaignSettings__c (
        	Name = 'cs1',
        	Campaign_Type__c = 'CampaignType1',
        	Engagement_Level__c = 1
        );
        EngagementCampaignSettings__c cs2 = new EngagementCampaignSettings__c (
        	Name = 'cs2',
        	Campaign_Type__c = 'CampaignType2',
        	Engagement_Level__c = 2
        );
        insert new EngagementCampaignSettings__c[] {cs1, cs2};        
        
        INCOPPS = settings.Include_Opps__c;
        INCMBR = settings.Include_Membership__c;
        NEWMBRLVL = settings.New_Member_Level__c.intvalue();
        RENMBRLVL = settings.Renewing_Member_Level__c.intvalue();        

		// also set settings for NPSP households (which drives rollups in NPSP) using dynamic DML
		if (GW_BATCH_EngagementRollup.IsNPSPHHInstalled) {
			SObject NPSPSettings;
			// first do a query to see if we have any settings recs in there, and delete them
			string soql = 'SELECT Id FROM npo02__Households_Settings__c';
			SObject[] settingsRecs = Database.query(soql);
			if (settingsRecs != null) delete settingsRecs;
			
			// now insert our own
			SObjectType token = Schema.getGlobalDescribe().get('npo02__Households_Settings__c');
			NPSPsettings = token.newSobject();
			NPSPsettings.put ('npo02__Enable_Opp_Rollup_Triggers__c',true);
			NPSPsettings.put ('npo02__Household_Rules__c','All New or Edited Contacts');
			NPSPsettings.put ('npo02__Membership_Record_Types__c',ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS);
			NPSPsettings.put ('npo02__Household_Contact_Roles_On__c',true);
			insert NPSPsettings;
			
		}

    }


	/* not used??
    static map<integer,string> getLvlNameMapForTests() {
        map<integer,string> lvlNameMapTest = new map<integer,string>();
        map<integer,string> lvlNameSettingMap = new map<integer,string>{
            1 => addNSPrefixET('Level_1_Name__c',true,false) , 
            2 => addNSPrefixET('Level_2_Name__c',true,false) , 
            3 => addNSPrefixET('Level_3_Name__c',true,false) , 
            4 => addNSPrefixET('Level_4_Name__c',true,false) , 
            5 => addNSPrefixET('Level_5_Name__c',true,false) , 
            6 => addNSPrefixET('Level_6_Name__c',true,false) , 
            7 => addNSPrefixET('Level_7_Name__c',true,false) , 
            8 => addNSPrefixET('Level_8_Name__c',true,false) };
        
        return lvlNameMapTest;
    }
    */
    
    
    @isTest (SeeAllData=true)
    public static void testLevelAssignment() { 

        // note: in addition to this batch process, this test relies on the GW_ContactTriggerBefore trigger
        string txtfield1 = 'Title';
        double txtfield1lvl = 6;
        string txtfield1FV = 'Board Member';
        setSettingsForTests(txtfield1, txtfield1FV, txtfield1lvl);  
        
        integer howMany = 25;
        Date datClose = System.Today();
        string GiftRectype = ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS;
        string MbrRectype = ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS;
        integer monthsRecent = settings.Timeframe_Recent__c.intvalue();
        integer monthsMedium = settings.Timeframe_Medium__c.intvalue();
        date startDateRecent = datClose.addMonths((monthsRecent*-1)+1);
        date startDateMedium = datClose.addMonths((monthsMedium*-1)+1);
        date startDateOld = datClose.addMonths((monthsMedium*-1)-12);
        date giftYearStartDate = datClose.addMonths((monthsRecent*-1));
        date cutoffDateRecent = system.today().addMonths(monthsRecent * -1);
        
        
        map<integer,string> lvlNameMapTest = new map<integer,string>();
        
        fetchDonorBreakpoints();
        integer DONORLVL1 = donorLvlMap.get(donorBreakpoints[0]).intvalue(); 
        integer DONORLVL2 = donorLvlMap.get(donorBreakpoints[1]).intvalue(); 
		
		// create one account, and spoof some donations this yr
		Account ac1 = new Account(Name='Doppleganger and Sons');
        if (IsGWBaseInstalled || IsNPSPHHInstalled) {
			ac1.put( addNSPrefixET('OppAmountLastNDays__c',false,true) , donorBreakpoints[1] - 5);
			ac1.put( addNSPrefixET('LastCloseDate__c',false,true) , startDateRecent);
			/*
			string ac1Id = ac1.Id;
			string fieldlist = addAllNSPrefixET('Id,Name,LastCloseDate__c,OppAmountLastNDays__c' , false, true);
			string soql = 'SELECT ' + fieldlist + ' FROM Account WHERE Id=:ac1Id LIMIT 1';
			Sobject[] ac1p = database.query(soql);
			system.debug(LOGGINGLEVEL.Warn,'ac1p: ' + ac1p);
			*/
        }
		insert ac1;

		                    
        // create & insert contact(s)
        Contact[] TestCons = ONEN_UnitTestData.CreateMultipleTestContacts(howMany);
        
        TestCons[5].Title = 'Board Member'; 
        TestCons[21].Email = 'test@test.com';   // this should give lvl 1
        TestCons[24].AccountId = ac1.Id;		// put one con in the account, and flag to inherit account's gifts
        TestCons[24].Award_Engagement_Levels_for_Org_Giving__c = true;
        insert TestCons;

		// have to update some fields after insert in order to spoof existing history of engagement changes
		// in order to get around trigger that blanks these out on insert (to avoid probs w/ cloning contacts)
        TestCons[0].Last_Engagement_Lvl_Chg_Datestamp__c = startDateOld.addMonths(-3);
        TestCons[1].Engagement_Level_Numeric__c = 2;   
        TestCons[1].Engagement_Peak_Numeric__c = 2;
        TestCons[1].Last_Engagement_Lvl_Chg_Datestamp__c = startDateOld.addMonths(-3);
        // for con 1 also put in an existing level chg log
        DateIntegerPair chg1 = new DateIntegerPair (startDateOld.addYears(-2),1);   
        DateIntegerPair chg2 = new DateIntegerPair (startDateOld.addYears(-1),2);
        list<DateIntegerPair> chgs = new list<DateIntegerPair> {chg1,chg2};
        TestCons[1].Engagement_Level_Change_Log__c = JSON.serialize(chgs);    
        TestCons[2].Engagement_Peak_Numeric__c = 1;
        TestCons[2].Last_Engagement_Lvl_Chg_Datestamp__c = startDateOld.addMonths(-3);   
        TestCons[2].First_Engagement_Level__c = 1;   
        TestCons[2].First_Engagement_Level_Date__c = startDateOld.addMonths(-3);   
        TestCons[10].Engagement_Level_Numeric__c = 1;  
        TestCons[10].Engagement_Peak_Numeric__c = 1;  
        TestCons[11].Engagement_Peak_Numeric__c = 5;
        update TestCons;  
        
        // now add 2 new contacts who are in existing households
        Contact[] consHH = ONEN_UnitTestData.CreateMultipleTestContactsInHouseholds(new list<Contact> {TestCons[16], TestCons[17]});
        consHH[0].FirstName = '16Spouse';
        consHH[1].FirstName = '17Spouse';
        insert consHH;
               
        // create a few activist campaigns
        Campaign camp1 = new Campaign (
            Name = 'Camp 1 This Yr Lvl 3',
            StartDate = startDateRecent,
            isActive = true,
            Leadership_Level__c = '3 - testLevel'
        );
        Campaign camp2 = new Campaign (
            Name = 'Camp 2 Last Yr Lvl 4',
            StartDate = startDateMedium,
            isActive = true,
            Leadership_Level__c = '4 - testLevelAlso'
        );
        Campaign camp3 = new Campaign (
            Name = 'Camp 3 This Yr Lvl 2',
            StartDate = startDateRecent,
            isActive = true,
            Leadership_Level__c = '2 - testLevelLower'
        );
        Campaign oldCamp = new Campaign (
            Name = 'Camp 4 Historical Lvl 3',
            StartDate = startDateOld,
            isActive = true,
            Leadership_Level__c = '5 - organizerlevel'
        );
        // this is an intentionally ridiculously long campaign, but testing that it will use the date
        // on the CM since within date range of camp.
        Campaign longCamp = new Campaign (
            Name = 'long lvl 4',
            StartDate = startDateMedium.addMonths(-2),
            EndDate = system.today().addMonths(1),
            isActive = true,
            Leadership_Level__c = '4 - testLevelAlso'
        );
        
        
        // add a bunch of campaigns of a particular type, for testing frequency rule
        integer i=1;
        Campaign[] onlineCamps = new Campaign[0];
        do {
            Campaign camp = new Campaign (
                Name = 'Online Campaign #' + i,
                StartDate = startDateRecent,
                isActive = true,
                Leadership_Level__c = '2 - testLevelLower',
                Type = 'Online Action'
            );
            onlineCamps.add(camp);
            i++;
        } while (i<=3);
        
        Campaign[] camps = new Campaign[]{camp1,camp2,camp3,oldCamp,longCamp};
        camps.addAll(onlineCamps); 
        insert camps;

        CampaignMember cm0 = new CampaignMember (
            CampaignId = camp1.Id,
            ContactId = TestCons[0].Id,
            Status = 'Responded'
        );      
        CampaignMember cm02 = new CampaignMember (
            CampaignId = oldCamp.Id,
            ContactId = TestCons[0].Id,
            Status = 'Responded'
        );      
        CampaignMember cm1 = new CampaignMember (
            CampaignId = camp2.Id,
            ContactId = TestCons[1].Id,
            Status = 'Responded'
        );      
        CampaignMember cm2 = new CampaignMember (
            CampaignId = camp1.Id,
            ContactId = TestCons[2].Id,
            Status = 'Responded'
        );      
        CampaignMember cm22 = new CampaignMember (
            CampaignId = camp2.Id,
            ContactId = TestCons[2].Id,
            Status = 'Responded'
        );      
        CampaignMember cm3 = new CampaignMember (
            CampaignId = oldCamp.Id,
            ContactId = TestCons[3].Id,
            Status = 'Responded'
        );      
        CampaignMember cm4 = new CampaignMember (
            CampaignId = camp1.Id,
            ContactId = TestCons[4].Id,
            Status = 'Responded'
        );      
        CampaignMember cm42 = new CampaignMember (
            CampaignId = camp2.Id,
            ContactId = TestCons[4].Id,
            Status = 'Responded'
        );      
        CampaignMember cm43 = new CampaignMember (
            CampaignId = camp3.Id,
            ContactId = TestCons[4].Id,
            Status = 'Responded'
        );      
        CampaignMember cm5 = new CampaignMember (
            CampaignId = camp1.Id,
            ContactId = TestCons[5].Id,
            Status = 'Responded'
        );      
        CampaignMember cm8 = new CampaignMember (
            CampaignId = camp1.Id,
            ContactId = TestCons[8].Id,
            Status = 'Responded'
        );      
        CampaignMember cm9 = new CampaignMember (
            CampaignId = camp3.Id,
            ContactId = TestCons[9].Id,
            Status = 'Responded'
        );      
        CampaignMember cm11 = new CampaignMember (
            CampaignId = longCamp.Id,
            ContactId = TestCons[11].Id,
            Status = 'Responded'
        );      
        CampaignMember cm112 = new CampaignMember (
            CampaignId = camp1.Id,
            ContactId = TestCons[11].Id,
            Status = 'Responded'
        );      
        CampaignMember cm14 = new CampaignMember (
            CampaignId = camp1.Id,
            ContactId = TestCons[14].Id,
            Status = 'Responded'
        );      
        CampaignMember cm15 = new CampaignMember (
            CampaignId = camp1.Id,
            ContactId = TestCons[15].Id,
            Status = 'Responded'
        );      
        CampaignMember cm19 = new CampaignMember (
            CampaignId = camp3.Id,
            //ContactId = TestCons[20].Id,
            ContactId = consHH[1].Id,
            Status = 'Responded'
        );
        CampaignMember cm23 = new CampaignMember (
            CampaignId = camp1.Id,
            ContactId = TestCons[23].Id,
            Status = 'Responded'
        );
        CampaignMember[] onlineCMs = new CampaignMember[0]; 
        for (Campaign c : onlineCamps) {
            CampaignMember cm = new CampaignMember (
                CampaignId = c.Id,
                ContactId = TestCons[18].Id,
                Status = 'Responded'
            );
            onlineCMs.add (cm);      
        }      

        CampaignMember[] cms = new CampaignMember[]{cm0,cm02,cm1,cm2,cm22,cm3,cm4,cm42,cm43,cm5,cm8,cm9,cm11,cm112,cm14,cm15,cm19,cm23};
        cms.AddAll(onlineCMs); 
        insert cms;
        system.debug ('cms inserted: ' + cms);

		// we need to bracket opp code with startTest and stopTest so that npsp rollups will
		// get processed (they must use future calls)
		test.startTest();
		
        // create new opps
        double smallAmt = (donorBreakpoints[1] / 2) - 1 ; 			// just less than half, so two small gifts doesn't put them into the next tier
        double majAmt = donorBreakpoints[2] - 5;   					// also assumes at least 3 lvls
        Contact[] ConsForSmallOpps = new Contact[]{TestCons[6],TestCons[7],TestCons[8],TestCons[9],TestCons[10],TestCons[12],TestCons[13],TestCons[16],TestCons[23]};
        Opportunity[] recentSmallOpps = ONEN_UnitTestData.OppsForContactList (ConsForSmallOpps,null,'Closed Won',startDateRecent,smallAmt,GiftRectype,null);
        Contact[] ConsForMajOpps = new Contact[]{TestCons[7],TestCons[17]};
        Opportunity[] recentMajOpps = ONEN_UnitTestData.OppsForContactList (ConsForMajOpps,null,'Closed Won',startDateRecent,majAmt,GiftRectype,null);
        Contact[] ConsOldMajOpps = new Contact[]{TestCons[8]};
        Opportunity[] oldMajOpps = ONEN_UnitTestData.OppsForContactList (ConsOldMajOpps,null,'Closed Won',startDateOld,majAmt,GiftRectype,null);
        Contact[] ConsMediumSmallOpps = new Contact[]{TestCons[9]};
        Opportunity[] medSmallOpps = ONEN_UnitTestData.OppsForContactList (ConsMediumSmallOpps,null,'Closed Won',startDateMedium,(smallAmt+10),GiftRectype,null);
        Contact[] ConsMbrshipThisYear = new Contact[]{TestCons[12],TestCons[13]};
        Opportunity[] mbrshipsThisYr = ONEN_UnitTestData.OppsForContactList (ConsMbrshipThisYear,null,'Closed Won',startDateRecent,smallAmt,MbrRectype,null);
        Contact[] ConsMbrshipLastYear = new Contact[]{TestCons[13]};
        Opportunity[] mbrshipsLastYr = ONEN_UnitTestData.OppsForContactList (ConsMbrshipLastYear,null,'Closed Won',startDateRecent.addYears(-1),smallAmt,MbrRectype,null);
        //now set membership fields
        Opportunity[] mbrOpps = new Opportunity[0];
        mbrOpps.addAll(mbrshipsThisYr);
        mbrOpps.addAll(mbrshipsLastYr);
    
    	if (IsGWBaseInstalled || IsNPSPHHInstalled) {
	        for (Opportunity opp : mbrOpps) {    
	            opp.put( addNSPrefixET('Membership_Start_Date__c',false,false), opp.CloseDate);
	            opp.put( addNSPrefixET('Membership_End_Date__c',false,false), opp.CloseDate.AddYears(1)); 
	        }
    	}
        // note that we also made sure contact 12 and 13 (those with membership),
        // have normal gift opps, to work around a bug in NPSP where they wouldn't
        // rollup membership opps if membership was in the excluded set, and the contact
        // had no other opps.

        Opportunity[] allOpps = new Opportunity[0];
        allOpps.addAll(recentSmallOpps);
        allOpps.addAll(recentMajOpps);
        allOpps.addAll(oldMajOpps);
        allOpps.addAll(medSmallOpps);
        allOpps.addAll(mbrOpps);
        insert allOpps;
               
        GW_BATCH_EngagementRollup myba = new GW_BATCH_EngagementRollup (true);
        
        // once the batch process is instantiated, borrow the level-levelname map which is created in constructor, for reference in assertions below
        lvlNameMapTest = myba.lvlNameMap;
        // set override on a few contacts - have to do this after we get the map
        TestCons[14].Engagement_Level_Override__c = lvlNameMapTest.get(4);
        TestCons[15].Engagement_Level_Override__c = lvlNameMapTest.get(4);
        TestCons[15].Engagement_Override_End_Date__c = system.today().addMonths(3);
        Contact[] overrideCons = new Contact[] {TestCons[14],TestCons[15]};
        update overrideCons;
        // then away we go
        ID batchprocessid = Database.executeBatch(myba);
        Test.StopTest();

        Id[] ConIDs = new Id[0];
        for (Contact con : TestCons) {
            ConIDs.add(con.Id);
        }
        for (Contact con : consHH) {
            ConIDs.add(con.Id);
        }
        
        // query for all the cons we started with
        map<Id,Contact> conP = new map<Id,Contact> ([SELECT Id,Name,FirstName,LastName,Engagement_Level__c,Engagement_Level_Numeric__c,Engagement_Peak__c,Engagement_Peak_Numeric__c,
            Last_Leadership_Action_Date__c,First_Action_Date_Curr_Level__c,Engagement_Level_Override__c,Engagement_Level_Override_Numeric__c,Engagement_Override_End_Date__c,
			Last_Engagement_Lvl_Chg_Datestamp__c,Former_Engagement_Level_Numeric__c,Engagement_Level_Change_Log__c,First_Engagement_Level__c,First_Engagement_Level_Date__c
			// temp disabled for security review ,Engagement_Level_One_Year_Ago__c	 
            FROM Contact WHERE Id IN :ConIDs]);
        system.debug (loggingLevel.WARN, 'conP:' + conP);
        
        // but now have to get them into the same order they started in
        
        
        // only this yr, but higher peak
        Contact con0P = conP.get(TestCons[0].Id);
        System.AssertEquals(3,con0P.Engagement_Level_Numeric__c);       
        System.AssertEquals(lvlNameMapTest.get(3),con0P.Engagement_Level__c);       
        System.AssertEquals(5,con0P.Engagement_Peak_Numeric__c);
        System.AssertEquals(lvlNameMapTest.get(5),con0P.Engagement_Peak__c);        
        // System.AssertEquals(system.today(),con0P.Engagement_Level_Mod_Date__c);      
        System.AssertEquals(startDateRecent,con0P.Last_Leadership_Action_Date__c);      
        System.AssertEquals(startDateRecent,con0P.First_Action_Date_Curr_Level__c);     
        System.AssertEquals(null,con0P.Engagement_Level_Override__c);       
        System.AssertEquals(null,con0P.Engagement_Override_End_Date__c);
        System.AssertEquals(null,con0P.Former_Engagement_Level_Numeric__c);
        System.AssertEquals(system.today(),DateFromDatetime(con0P.Last_Engagement_Lvl_Chg_Datestamp__c));
        System.AssertEquals(3,con0P.First_Engagement_Level__c);
        System.AssertEquals(startDateRecent,con0P.First_Engagement_Level_Date__c);
        chgs = (list<DateIntegerPair>) JSON.deserialize(con0p.Engagement_Level_Change_Log__c , list<DateIntegerPair>.class);
        system.Assert (chgs.size()==1);
        system.Assert (chgs[0].d == system.today());      
        system.Assert (chgs[0].i == 3);      

        // only last yr
        Contact con1P = conP.get(TestCons[1].Id);
        System.AssertEquals(4,con1P.Engagement_Level_Numeric__c);       
        System.AssertEquals(4,con1P.Engagement_Peak_Numeric__c);
        System.AssertEquals(lvlNameMapTest.get(4),con1P.Engagement_Peak__c);
        System.AssertEquals(startDateMedium,con1P.Last_Leadership_Action_Date__c);
        // also test that the level & date stamp on the campaign membership worked
        CampaignMember cm1p = [SELECT Id,Engagement_Level_At_Insert__c,Level_Change_Datestamp_At_Insert__c FROM CampaignMember WHERE Id=:cm1.Id LIMIT 1];
        System.AssertEquals(2,cm1p.Engagement_Level_At_Insert__c);  
        System.AssertEquals(startDateOld.addMonths(-3),cm1p.Level_Change_Datestamp_At_Insert__c);
        // first eng. level & date should both be null since weren't set by the batch
        System.AssertEquals(null,con1p.First_Engagement_Level__c);
        System.AssertEquals(null,con1p.First_Engagement_Level_Date__c);
        // should have added this chg to the list of chgs already in the contact  
        chgs = (list<DateIntegerPair>) JSON.deserialize(con1p.Engagement_Level_Change_Log__c , list<DateIntegerPair>.class);
        system.Assert (chgs.size()==3);
        system.Assert (chgs[0].d < system.today());      
        system.Assert (chgs[2].d == system.today());
        // temp disabled for security review	system.AssertEquals (2,con1p.Engagement_Level_One_Year_Ago__c);   		// based on change log
        
        // both years, last yr greater
        Contact con2P = conP.get(TestCons[2].Id);
        System.AssertEquals(4,con2P.Engagement_Level_Numeric__c);
        System.AssertEquals(lvlNameMapTest.get(4),con2P.Engagement_Level__c);       
        System.AssertEquals(startDateRecent,con2P.Last_Leadership_Action_Date__c);          
        System.AssertEquals(startDateMedium,con2P.First_Action_Date_Curr_Level__c); 
        // these should still be the same as before the batch
        System.AssertEquals(1,con2P.First_Engagement_Level__c); 
        System.AssertEquals(startDateOld.addMonths(-3),con2P.First_Engagement_Level_Date__c); 
        // temp disabled for security review	system.AssertEquals (null,con2p.Engagement_Level_One_Year_Ago__c);		// b/c lacking change log 
        
        // only peak, nothing recent
        Contact con3P = conP.get(TestCons[3].Id);
        System.AssertEquals(0,con3P.Engagement_Level_Numeric__c);       
        System.AssertEquals(5,con3P.Engagement_Peak_Numeric__c);
        System.AssertEquals(lvlNameMapTest.get(5),con3P.Engagement_Peak__c);
        System.AssertEquals(startDateOld,con3P.Last_Leadership_Action_Date__c); 
        System.AssertEquals(null,con3P.First_Action_Date_Curr_Level__c);  // b/c no actions at level 0  

        // this yr, but board member picklist
        Contact con5P = conP.get(TestCons[5].Id);
        System.AssertEquals(txtfield1lvl,con5P.Engagement_Level_Numeric__c);
        System.AssertEquals(lvlNameMapTest.get(txtfield1lvl.intvalue()),con5P.Engagement_Level__c);                
        System.AssertEquals(txtfield1lvl,con5P.Engagement_Peak_Numeric__c);
        System.AssertEquals(startDateRecent,con5P.Last_Leadership_Action_Date__c);  // this doesn't care about the lvl
        System.AssertEquals(system.today(),con5P.First_Action_Date_Curr_Level__c);  // b/c no actions, just chkbox

        if (INCOPPS) {
            // recent small donation only
            Contact con6P = conP.get(TestCons[6].Id);
            System.AssertEquals(DONORLVL1,con6P.Engagement_Level_Numeric__c);        
            System.AssertEquals(DONORLVL1,con6P.Engagement_Peak_Numeric__c);
            System.AssertEquals(lvlNameMapTest.get(DONORLVL1),con6P.Engagement_Peak__c);
            System.AssertEquals(startDateRecent,con6P.Last_Leadership_Action_Date__c);  
            System.AssertEquals(startDateRecent,con6P.First_Action_Date_Curr_Level__c);
            
            if (isNPSPHHInstalled) {
            	// while we're at it, also check that the Donor? flag was set by trigger (NPSP only) - used in reports
            	string donorFieldname = addNSPrefixET('IsDonor__c',true,false);
            	Id con6PId = con6P.Id;
            	string soql = 'SELECT Id,' + donorFieldname + ' FROM Contact WHERE Id =:con6PId';
            	SObject[] results = database.query(soql);
            	contact con6PP = (Contact) results[0];
            	system.assert (con6PP.get(donorFieldname)==true);  
            }
    
            // recent small donation & maj donation (should work out to donor tier 3) 
            Contact con7P = conP.get(TestCons[7].Id);
            System.AssertEquals(DONORLVL2+1,con7P.Engagement_Level_Numeric__c);
            System.AssertEquals(lvlNameMapTest.get(DONORLVL2+1),con7P.Engagement_Level__c);        
            System.AssertEquals(DONORLVL2+1,con7P.Engagement_Peak_Numeric__c);
            System.AssertEquals(startDateRecent,con7P.Last_Leadership_Action_Date__c);  
            System.AssertEquals(startDateRecent,con7P.First_Action_Date_Curr_Level__c);
    
            // historical maj gift, recent small gift & campaign
            Contact con8P = conP.get(TestCons[8].Id);
            integer lvlnow = (DONORLVL1 > 3) ? DONORLVL1 : 3;
            System.AssertEquals(lvlnow,con8P.Engagement_Level_Numeric__c);
            System.AssertEquals(lvlNameMapTest.get(lvlnow),con8P.Engagement_Level__c);          
            System.AssertEquals(DONORLVL2,con8P.Engagement_Peak_Numeric__c);
    
            // 2 gifts, one lesser action
            Contact con9P = conP.get(TestCons[9].Id);
            System.AssertEquals(DONORLVL2,con9P.Engagement_Level_Numeric__c);        
            System.AssertEquals(DONORLVL2,con9P.Engagement_Peak_Numeric__c);
            System.AssertEquals(lvlNameMapTest.get(DONORLVL2),con9P.Engagement_Peak__c);
            System.AssertEquals(startDateRecent,con9P.Last_Leadership_Action_Date__c);  
            System.AssertEquals(startDateRecent,con9P.First_Action_Date_Curr_Level__c);
    
            // gift this yr
            Contact con10P = conP.get(TestCons[10].Id);
            System.AssertEquals(DONORLVL1,con10P.Engagement_Level_Numeric__c);       
            System.AssertEquals(DONORLVL1,con10P.Engagement_Peak_Numeric__c);
            System.AssertEquals(lvlNameMapTest.get(DONORLVL1),con10P.Engagement_Peak__c);
            // System.AssertEquals(system.today().addMonths(-2),con10P.Engagement_Level_Mod_Date__c);
            System.AssertEquals(1,con10P.Former_Engagement_Level_Numeric__c);		// we gave him this level on contact insert        
	        System.AssertEquals(system.today(),DateFromDatetime(con10P.Last_Engagement_Lvl_Chg_Datestamp__c));   
            
            /* deprecated
            // HH mbr w/ no other activity, shouldn't get HH donation credit
            Contact con19P = conP.get(consHH[0].Id);
            System.AssertEquals(0,con19P.Engagement_Level_Numeric__c);        
            System.AssertEquals(0,con19P.Engagement_Peak_Numeric__c);
            System.AssertEquals(null,con19P.Last_Leadership_Action_Date__c);
            */
              
            // HH mbr, should get HH donation credit
            Contact con20P = conP.get(consHH[1].Id);
            System.AssertEquals(DONORLVL2,con20P.Engagement_Level_Numeric__c);        
            System.AssertEquals(DONORLVL2,con20P.Engagement_Peak_Numeric__c);
            System.AssertEquals(startDateRecent,con20P.Last_Leadership_Action_Date__c);
            System.AssertEquals(system.today(),con20P.First_Action_Date_Curr_Level__c);		// right now HH members don't time travel for level start date

            // gift this yr but higher level from campaign
            Contact con23P = conP.get(TestCons[23].Id);
            System.AssertEquals(3,con23P.Engagement_Level_Numeric__c);       
            System.AssertEquals(3,con23P.Engagement_Peak_Numeric__c);

            // inherits level from account opps!
            Contact con24P = conP.get(TestCons[24].Id);
            System.AssertEquals(DONORLVL1,con24P.Engagement_Level_Numeric__c);       
            System.AssertEquals(DONORLVL1,con24P.Engagement_Peak_Numeric__c);

        }

        // in long campaign, but CM date is recent - also has pre-existing higher peak
        Contact con11P = conP.get(TestCons[11].Id);
        System.AssertEquals(4,con11P.Engagement_Level_Numeric__c);
        System.AssertEquals(lvlNameMapTest.get(4),con11P.Engagement_Level__c);          
        System.AssertEquals(5,con11P.Engagement_Peak_Numeric__c);
        System.AssertEquals(system.today(),con11P.Last_Leadership_Action_Date__c);  
        System.AssertEquals(system.today(),con11P.First_Action_Date_Curr_Level__c);

        // over frequency limit for campaigns, should get higher level
        Contact con18P = conP.get(TestCons[18].Id);
        System.AssertEquals(3,con18P.Engagement_Level_Numeric__c);
        System.AssertEquals(3,con18P.Engagement_Peak_Numeric__c);
        System.AssertEquals(startDateRecent,con18P.Last_Leadership_Action_Date__c);  
        System.AssertEquals(system.today(),con18P.First_Action_Date_Curr_Level__c);			// we don't attempt to back-date for frequency rules

        /* omitting this for now, pending decision whether to include
        // decayed from last yr
        Contact con4P = conP.get(TestCons[4].Id);
        System.AssertEquals(3,con4P.Engagement_Level_Numeric__c);
        System.AssertEquals(lvlNameMapTest.get(3),con4P.Engagement_Level__c);               
        System.AssertEquals(4,con4P.Engagement_Peak_Numeric__c);
        System.AssertEquals(lvlNameMapTest.get(4),con4P.Engagement_Peak__c);
        System.AssertEquals(startDateRecent,con4P.First_Action_Date_Curr_Level__c); 
        */
        
        IF (INCMBR) {
            // mbrship this yr only
            Contact con12P = conP.get(TestCons[12].Id);
            System.AssertEquals(NEWMBRLVL,con12P.Engagement_Level_Numeric__c);      
            System.AssertEquals(NEWMBRLVL,con12P.Engagement_Peak_Numeric__c);
            System.AssertEquals(lvlNameMapTest.get(NEWMBRLVL),con12P.Engagement_Peak__c);
            System.AssertEquals(startDateRecent,con12P.Last_Leadership_Action_Date__c); 
            /*System.Assert(startDateRecent == con12P.First_Action_Date_Curr_Level__c ||
            	cutoffDateRecent == con12P.First_Action_Date_Curr_Level__c); */
            System.AssertEquals(system.today(),con12P.First_Action_Date_Curr_Level__c);		// currently no back-dating for membership
            	
    
            // renewing mbr this yr
            Contact con13P = conP.get(TestCons[13].Id);
            System.AssertEquals(RENMBRLVL,con13P.Engagement_Level_Numeric__c);
            System.AssertEquals(lvlNameMapTest.get(RENMBRLVL),con13P.Engagement_Level__c);          
            System.AssertEquals(RENMBRLVL,con13P.Engagement_Peak_Numeric__c);
        }

        // lvl 3 this yr, but overridden to 4 w/ default date
        Contact con14P = conP.get(TestCons[14].Id);
        System.AssertEquals(4,con14P.Engagement_Level_Numeric__c);
        System.AssertEquals(lvlNameMapTest.get(4),con14P.Engagement_Level__c);          
        System.AssertEquals(4,con14P.Engagement_Peak_Numeric__c);
        System.AssertEquals(4,con14P.Engagement_Level_Override_Numeric__c);     
        System.AssertEquals(system.today().addMonths(12),con14P.Engagement_Override_End_Date__c);   

        // ditto, but used custom end date
        Contact con15P = conP.get(TestCons[15].Id);
        System.AssertEquals(4,con15P.Engagement_Level_Numeric__c);
        System.AssertEquals(lvlNameMapTest.get(4),con15P.Engagement_Level__c);          
        System.AssertEquals(4,con15P.Engagement_Peak_Numeric__c);
        System.AssertEquals(4,con15P.Engagement_Level_Override_Numeric__c);     
        System.AssertEquals(system.today().addMonths(3),con15P.Engagement_Override_End_Date__c);    

        // lvl 1 due to email field being populated
        Contact con21P = conP.get(TestCons[21].Id);
        System.AssertEquals(1,con21P.Engagement_Level_Numeric__c);        
        System.AssertEquals(null,con21P.Last_Leadership_Action_Date__c);
                 
        // and one that has nothing!
        Contact con22P = conP.get(TestCons[22].Id);
        System.AssertEquals(0,con22P.Engagement_Level_Numeric__c);     
        
        
        // also test for conversions
        map<id,CampaignMember> cmsPmap = new map<id,CampaignMember>( [SELECT Id,CampaignId,ContactId,Status,Engagement_Conversion__c,
        							Engagement_Conversion_To_Level__c,Engagement_Conversion_From_Level__c,Engagement_Conversion_Type__c,
        							Engagement_List_Growth__c 
        							FROM CampaignMember WHERE Id IN :cms] );
        
        // for con0, the old CM shouldn't be a conversion, but the newer one should
        system.AssertEquals (false , cmsPmap.get(cm02.Id).Engagement_Conversion__c );
        system.AssertEquals (true , cmsPmap.get(cm0.Id).Engagement_Conversion__c );
        system.AssertEquals (0 , cmsPmap.get(cm0.Id).Engagement_Conversion_From_Level__c );
        system.AssertEquals ('New' , cmsPmap.get(cm0.Id).Engagement_Conversion_Type__c );
        system.AssertEquals (true , cmsPmap.get(cm0.Id).Engagement_List_Growth__c );
        
        // for con2, the older CM is a conversion but isn't list growth since had existing peak, even though curr level before was 0
        system.AssertEquals (true , cmsPmap.get(cm22.Id).Engagement_Conversion__c );
        system.AssertEquals (0 , cmsPmap.get(cm22.Id).Engagement_Conversion_From_Level__c );
        system.AssertEquals ('New', cmsPmap.get(cm22.Id).Engagement_Conversion_Type__c );
        system.AssertEquals (false, cmsPmap.get(cm22.Id).Engagement_List_Growth__c );
        
        // for con5, the CM isn't a conversion since he gets level from field value
        system.AssertEquals (false , cmsPmap.get(cm5.Id).Engagement_Conversion__c );
        system.AssertEquals (null , cmsPmap.get(cm5.Id).Engagement_Conversion_From_Level__c );
        system.AssertEquals (null , cmsPmap.get(cm5.Id).Engagement_Conversion_Type__c );
        system.AssertEquals (false , cmsPmap.get(cm5.Id).Engagement_List_Growth__c );
        
        // for con11, the lvl 4 CM is a conversion, but not a "virgin" conversion
        system.AssertEquals (true , cmsPmap.get(cm11.Id).Engagement_Conversion__c );
        system.AssertEquals ('Returning' , cmsPmap.get(cm11.Id).Engagement_Conversion_Type__c );
        system.AssertEquals (false , cmsPmap.get(cm11.Id).Engagement_List_Growth__c );
        
        // con8 CM is conversion since same date as opp
        system.AssertEquals (true , cmsPmap.get(cm8.Id).Engagement_Conversion__c );
        system.AssertEquals ('New' , cmsPmap.get(cm8.Id).Engagement_Conversion_Type__c );
        
        
        if (INCOPPS) {
	        // and conversions for opps
	        map<id,Opportunity> oppPmap = new map<id,Opportunity>();
	        OpportunityContactRole[] conroles = [SELECT OpportunityId,ContactId,Role,Opportunity.Engagement_Conversion__c,
	        									Opportunity.Engagement_Conversion_To_Level__c,Opportunity.Engagement_Conversion_From_Level__c,Opportunity.Engagement_Conversion_Type__c
	        									FROM OpportunityContactRole WHERE OpportunityId IN :allOpps AND IsPrimary = True];
	        for (OpportunityContactRole conrole : conroles) {
	        	oppPmap.put (conrole.OpportunityId,conrole.Opportunity);
	        }
	
			// this one is not a conversion, since they got higher level from campaign
	        Id con23oppId = recentSmallOpps[8].Id; 		// first in, first out
	        system.assertEquals (false, oppPmap.get(con23oppId).Engagement_Conversion__c);
	        system.assertEquals (null , oppPmap.get(con23oppId).Engagement_Conversion_From_Level__c);
	        system.assertEquals (null, oppPmap.get(con23oppId).Engagement_Conversion_Type__c);
	        system.assertEquals (false, oppPmap.get(con23oppId).Engagement_List_Growth__c);
			
	        
	        // this one should be a conversion, he started from lvl 0 and has no campaigns
	        Id con6oppId = recentSmallOpps[0].Id; 		// first in, first out
	        system.assertEquals (true , oppPmap.get(con6oppId).Engagement_Conversion__c);
	        system.assertEquals (0 , oppPmap.get(con6oppId).Engagement_Conversion_From_Level__c);
	        system.assertEquals ('New', oppPmap.get(con6oppId).Engagement_Conversion_Type__c);
	        system.assertEquals (true, oppPmap.get(con6oppId).Engagement_List_Growth__c);
	        
	        // con 8 opp shouold not be conversion since same data as CM, and campaigns win the tie
	        Id con8oppId = recentSmallOpps[2].Id; 		// first in, first out
	        system.assertEquals (false, oppPmap.get(con8oppId).Engagement_Conversion__c);
        }
                
        // finally test that engagement fields are blanked out on clone
        Contact cloneCon = con0P.clone(false,true);	// deep clone not including ID
        insert CloneCon;
        Contact cloneConP = [SELECT Id,Name,FirstName,LastName,Engagement_Level__c,Engagement_Level_Numeric__c,Engagement_Peak__c,Engagement_Peak_Numeric__c,
            Last_Leadership_Action_Date__c,First_Action_Date_Curr_Level__c,Engagement_Level_Override__c,Engagement_Level_Override_Numeric__c,Engagement_Override_End_Date__c,
			Last_Engagement_Lvl_Chg_Datestamp__c,Former_Engagement_Level_Numeric__c
            FROM Contact WHERE Id = :cloneCon.Id LIMIT 1];
        system.assertEquals (null,CloneConP.Engagement_Peak__c);
        system.assertEquals (null,CloneConP.Engagement_Level__c);
        system.assertEquals (null,CloneConP.Last_Engagement_Lvl_Chg_Datestamp__c);
        system.assertEquals (null,CloneConP.First_Action_Date_Curr_Level__c);
    }
    
	@isTest (SeeAllData=true)
    public static void testCampaignDefaults() { 

        // this test relies on the GW_CampaignTriggerBefore trigger
        string txtfield1 = 'Title';
        double txtfield1lvl = 6;
        string txtfield1FV = 'Board Member';
        setSettingsForTests(txtfield1, txtfield1FV, txtfield1lvl); 
        
		Campaign cmp1 = new Campaign (
		    Name = 'Campaign 1',
		    Type = 'CampaignType1'
		);
		Campaign cmp2 = new Campaign (
		    Name = 'Campaign 2',
		    Type = 'CampaignType2'
		);
		Campaign cmp3 = new Campaign (
		    Name = 'Campaign 3',
		    Type = 'CampaignType3'
		);
		Campaign cmp4 = new Campaign (
		    Name = 'Campaign 4'
		);
		list<Campaign> listCmp = new list<Campaign>{cmp1, cmp2, cmp3, cmp4};
        insert listCmp;
        
        listCmp = [select Id, Engagement_Level_Numeric__c from Campaign where Id in :listCmp order by Name];
        system.assert(listCmp.size() == 4);
        system.assertEquals(1, listCmp[0].Engagement_Level_Numeric__c);
        system.assertEquals(2, listCmp[1].Engagement_Level_Numeric__c);
        system.assertEquals(null, listCmp[2].Engagement_Level_Numeric__c);
        system.assertEquals(null, listCmp[3].Engagement_Level_Numeric__c);
                 
    }
    
    private static date DateFromDatetime (datetime dt) {
    	Date d = Date.newInstance(dt.year(),dt.Month(),dt.day());
    	return d;
    }
            
}