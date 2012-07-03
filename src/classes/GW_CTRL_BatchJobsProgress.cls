/*******************************************************************************************************
* @author Jason Venable, http://www.tehnrd.com/batch-apex-status-bar/
* @date 01/01/2010
* @description Controller for component that displays progress for batch apex jobs
*
* It is called statically, and therefore will supply the same information to all calls made from
* within one transaction, or set of trigger calls. This is beneficial because this info should
* be the same for all calls in a transaction, and by calling it statically we reduce the calls
* that are made, making the total transaction more efficient.
*
* modified 6/12/12 by Matthew Scholtz for Groundwire
*  to omit BatchApexWorker records, and to limit to batches created in last 2 hours
*
* This program is released under the GNU General Public License. http://www.gnu.org/licenses/
*/
public with sharing class GW_CTRL_BatchJobsProgress {
 
    private List<BatchJob> batchJobs;
    
	/*******************************************************************************************************
    * @description number of batch jobs the control will monitor
	*/ 	
    public Integer numberOfJobs {get; set;}

	/*******************************************************************************************************
    * @description label to display at the top of the progress meter
	*/ 	
    public String batchComponentLabel {get; set;}
 
	/*******************************************************************************************************
    * @description query for the current batch job progress
	*/ 	
    public List<BatchJob> getBatchJobs() {
        //Create new list of BatchJobs, a wrapper class that includes the job and percent complete.
        batchJobs = new List<BatchJob>();
 
        //If number of jobs was not defined, default to 20
        if(numberOfJobs== null || numberofJobs <= 0) {
            numberofJobs = 20;
        }
        
        if(batchComponentLabel== null) {
            batchComponentLabel = 'Batch Apex Jobs';
        }
 
        //Query the Batch apex jobs
        datetime cutoff = System.now().addHours(-2);
        for(AsyncApexJob a : [select TotalJobItems, Status, NumberOfErrors, MethodName, JobType, JobItemsProcessed, Id, 
        							CreatedDate, CreatedById, CompletedDate, ApexClassId, ApexClass.Name 
        							From AsyncApexJob 
        							Where JobType != 'BatchApexWorker' And CreatedDate >= :cutoff
        							order by CreatedDate desc limit :numberOfJobs]) {
            Double itemsProcessed = a.JobItemsProcessed;
            Double totalItems = a.TotalJobItems;
 
            BatchJob j = new BatchJob();
            j.job = a;
 
            //Determine the pecent complete based on the number of batches complete
            if(a.status == 'Completed') {
            	j.percentComplete = 100;
            //Determine the pecent complete based on the number of batches complete
            } else if (totalItems == 0) {
                //A little check here as we don't want to divide by 0.
                j.percentComplete = 0;
            } else {
                j.percentComplete = ((itemsProcessed  / totalItems) * 100.0).intValue();
            }
 
            batchJobs.add(j);
        }
        return batchJobs;
    }
 
    
	/*******************************************************************************************************
    * @description wrapper class includes the job itself and a value for the percent complete
	*/ 	
    public Class BatchJob{
        public AsyncApexJob job {get; set;}
        public Integer percentComplete {get; set;}
    }
 
    //--------------------TEST METHOD------------------------
    static testMethod void batchStatusBarTest(){
        GW_CTRL_BatchJobsProgress controller = new GW_CTRL_BatchJobsProgress();
        controller.getBatchJobs();
    }
    
}