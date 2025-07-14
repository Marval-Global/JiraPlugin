<%@ WebHandler Language="C#" Class="ApiHandler" %>

using System;
using System.IO;
using System.Net;
using System.Text;
using System.Web;
using System.Dynamic;
using System.Collections.Generic;
using System.Globalization;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System.Threading;
using MarvalSoftware;
using MarvalSoftware.UI.WebUI.ServiceDesk.RFP.Plugins;
using MarvalSoftware.ServiceDesk.Facade;
using MarvalSoftware.DataTransferObjects;
using System.Threading.Tasks;
using System.Linq;
using System.Text.RegularExpressions;
using Serilog;

public static class ObjectExtensions
{
    public static bool HasProperty(this object obj, string propertyName)
    {
        return obj.GetType().GetProperty(propertyName) != null;
    }
}

/// <summary>
/// ApiHandler
/// </summary>
public class ApiHandler : PluginHandler
{

  public class State
    {
        public int Id { get; set; }
        public int StatusId { get; set; }
        public string Name { get; set; }
        public List<int> NextWorkflowStatusIds { get; set; }
    }
    public class EntityData
    {
        public int id { get; set; }
        public string name { get; set; }
        public List<State> states { get; set; }
    }

    public class Entity
    {
        public EntityData data { get; set; }
    }

    public class WorkflowReadResponse
    {
        public EntityData data { get; set; }
    }
    //properties
    private string CustomFieldName
    {
        get
        {
            return this.GlobalSettings["@@JIRACustomFieldName"];
        }
    }


    private string BaseUrl
    {
        get
        {
            return this.GlobalSettings["@@JIRABaseUrl"];
        }
    }

    public class FormDetails
    {
        public string Name { get; set; }
        // Add other properties as needed
    }

    public class Response
    {
        public List<FormDetails> Forms { get; set; }
        // Add other properties as needed
    }

    private string ApiBaseUrl
    {
        get
        {
            return this.BaseUrl + "rest/api/latest/";
        }
    }

    public class FormField
    {
        public string Name { get; set; }
        public object Value { get; set; }
    }

    public class FormFieldSet
    {
        public List<FormField> Fields { get; set; }
    }

    public class Form
    {
        public List<FormFieldSet> FieldSets { get; set; }
    }

    private string MSMBaseUrl
    {
        get
        {
            return "https://" + HttpContext.Current.Request.Url.Host + MarvalSoftware.UI.WebUI.ServiceDesk.WebHelper.ApplicationPath;
        }
    }
    private string CustomFieldId { get; set; }
    private string MsmApiKey
    {
        get
        {
            return this.GlobalSettings["@@MSMAPIKey"];
        }
    }

    private string Username
    {
        get
        {
            return this.GlobalSettings["@@JIRAUsername"];
        }
    }

    private string Password
    {
        get
        {
            return this.GlobalSettings["@@JIRAPassword"];
        }
    }

    private string JiraCredentials
    {
        get
        {
            return ApiHandler.GetEncodedCredentials(string.Format("{0}:{1}", this.Username, this.Password));
        }
    }

    private IWebProxy Proxy
    {
        get
        {
            IWebProxy proxy = System.Net.WebRequest.GetSystemWebProxy();
            if (proxy != null && this.ProxyCredentials != null)
            {
                proxy.Credentials = this.ProxyCredentials;
            }
            return proxy;
        }
    }

    private string ProxyUsername
    {
        get
        {
            return GlobalSettings["@@ProxyUsername"];
        }
    }

    private string ProxyPassword
    {
        get
        {
            return GlobalSettings["@@ProxyPassword"];
        }
    }

    private ICredentials ProxyCredentials
    {
        get
        {
            if (String.IsNullOrWhiteSpace(this.ProxyUsername))
                return null;
            return new NetworkCredential(this.ProxyUsername, this.ProxyPassword);
        }
    }
    

    private string JIRAFieldType { get; set; }
    private string JIRAFieldID { get; set; }
    private string JiraIssueNo { get; set; }

    private string JiraSummary { get; set; }

    private string JiraType { get; set; }

    private string JiraProject { get; set; }

    private string JiraReporter { get; set; }

    private string AttachmentIds { get; set; }

    private string MsmContactEmail { get; set; }

    private string IssueUrl { get; set; }

    //fields
    private int msmRequestNo;

    private static int isInitialised = 0;
    private static readonly int second = 1;
    private static readonly int minute = 60 * ApiHandler.second;
    private static readonly int hour = 60 * ApiHandler.minute;
    private static readonly int day = 24 * ApiHandler.hour;

    /// <summary>
    /// Handle Request
    /// </summary>
    public override void HandleRequest(HttpContext context)
    {
        this.ProcessParamaters(context.Request);
        var action = context.Request.QueryString["action"];
        this.RouteRequest(action, context);
    }

    public override bool IsReusable
    {
        get { return false; }
    }

    /// <summary>
    /// Get Paramaters from QueryString
    /// </summary>
    private void ProcessParamaters(HttpRequest httpRequest)
    {
        int.TryParse(httpRequest.Params["requestNumber"], out this.msmRequestNo);
        this.JiraIssueNo = httpRequest.Params["issueNumber"] ?? string.Empty;
        this.JiraSummary = httpRequest.Params["issueSummary"] ?? string.Empty;
        this.JiraType = httpRequest.Params["issueType"] ?? string.Empty;
        this.JiraProject = httpRequest.Params["project"] ?? string.Empty;
        this.JiraReporter = httpRequest.Params["reporter"] ?? string.Empty;
        this.AttachmentIds = httpRequest.Params["attachments"] ?? string.Empty;
        this.MsmContactEmail = httpRequest.Params["contactEmail"] ?? string.Empty;
        this.IssueUrl = httpRequest.Params["issueUrl"] ?? string.Empty;
    }

    /// <summary>
    /// Route Request via Action
    /// </summary>
    private void RouteRequest(string action, HttpContext context)
    {
        HttpWebRequest httpWebRequest;
        // Only run GetJIRAFielInformation if the prerequisite check is done, otherwise it will fail before this. 
         this.GetJIRAFielInformation();
        if (ApiHandler.isInitialised == 1) {
            this.GetJIRAFielInformation();
        }
        switch (action)
        {
            case "PreRequisiteCheck":
                ApiHandler.isInitialised = 1;
                context.Response.Write(this.PreRequisiteCheck());
                
                break;
            case "GetJiraIssues":         
                context.Response.Write(JsonConvert.SerializeObject(this.ReturnMatchingJIRARequests()));
                break;
            case "LinkJiraIssue":
                this.UpdateJiraIssue(this.msmRequestNo);
                context.Response.Write(JsonConvert.SerializeObject(this.ReturnMatchingJIRARequests()));
                break;
            case "UnlinkJiraIssue":
                context.Response.Write(this.UpdateJiraIssue(null));
                break;
            case "CreateJiraIssue":
                dynamic result = this.CreateJiraIssue();
                if (result.errors != null) {
                    context.Response.Write(result);
                } else {
                   httpWebRequest = ApiHandler.BuildRequest(this.ApiBaseUrl + string.Format("issue/{0}", result.key), null, "GET", this.Proxy);
                   context.Response.Write(ApiHandler.ProcessRequest(httpWebRequest, "Basic " + this.JiraCredentials));
                }
                break;
            case "MoveStatus":
            Log.Information("Moving status from JIRA");
                this.MoveMSMStatus(context.Request);
                break;
            case "GetProjectsIssueTypes":
                var results = this.GetJiraProjectIssueTypeMapping();
                context.Response.Write(JsonConvert.SerializeObject(results));
                break;
            case "GetJiraUsers":
                httpWebRequest = ApiHandler.BuildRequest(this.ApiBaseUrl + string.Format("user/search?query={0}", this.MsmContactEmail), null, "GET", this.Proxy);
                context.Response.Write(ApiHandler.ProcessRequest(httpWebRequest, "Basic " + this.JiraCredentials));
                break;
            case "SendAttachments":
                if (!string.IsNullOrEmpty(this.AttachmentIds))
                {
                    var attachmentNumIds = Array.ConvertAll(this.AttachmentIds.Split(','), Convert.ToInt32);
                    var att = this.GetAttachmentDtOs(attachmentNumIds);
                    var attachmentResult = this.PostAttachments(att, this.JiraIssueNo);
                    context.Response.Write(attachmentResult);
                }
                break;
            case "ViewSummary":
                httpWebRequest = ApiHandler.BuildRequest(this.IssueUrl, null, "GET", this.Proxy);
                context.Response.Write(this.BuildPreview(context, ApiHandler.ProcessRequest(httpWebRequest, "Basic " + this.JiraCredentials)));
                break;
        }
    }

    private int[] ConvertStringToArray(string input)
    {
        int[] numbers = Array.Empty<int>();
        if (string.IsNullOrEmpty (input)) {
           return numbers;
        }
        // Split the input string by commas and remove any surrounding quotes
        string[] numberStrings = input.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries).Select(s => s.Trim('\"')).ToArray();
        // Convert the string array to an integer array
        numbers = Array.ConvertAll(numberStrings, int.Parse);

        return numbers;
    }

    private string ConvertArrayToString(int[] numbers)
    {
        // Convert the integer array to a string with comma-separated values
        string result = string.Join(",", numbers);
        // Add quotes around each number
        result = string.Join(",", numbers.Select(n => string.Format("\"{0}\"", n)));
        return result;
    }
    public class WorkflowInfo
{
    public int WorkflowId { get; set; }
    public int StatusId { get; set; }
}
    private WorkflowInfo GetRequestWorkflowId(int requestId)
{
    Log.Information("BaseURL is " + this.MSMBaseUrl);
    var httpWebRequest2 = ApiHandler.BuildRequest(this.MSMBaseUrl + string.Format("/api/serviceDesk/operational/requests/{0}", requestId), null, "GET");
    Log.Information("base url " + this.MSMBaseUrl);
    Log.Information("http request is " + httpWebRequest2);
    // var teststuff = ApiHandler.ProcessRequest(httpWebRequest2, "Bearer " + this.MsmApiKey);
    JObject requestIdResponse = JObject.Parse(ApiHandler.ProcessRequest(httpWebRequest2, "Bearer " + this.MsmApiKey));
    Log.Information("API key is " + this.MsmApiKey);
    Log.Information("request id " + requestId);
     Log.Information("Have response from getting request info as " + requestIdResponse);
    var workflowIdToken = requestIdResponse["entity"]["data"]["requestStatus"]["workflowStatus"]["workflow"]["id"];
    var statusIdToken = requestIdResponse["entity"]["data"]["requestStatus"]["workflowStatus"]["id"];

    int workflowId = workflowIdToken.Value<int>();
    int statusId = statusIdToken.Value<int>();

    return new WorkflowInfo { WorkflowId = workflowId, StatusId = statusId };
}

private void MoveMSMStatus(HttpRequest httpRequest)
    {

       // Get all project ids from Marval Projects
       // this.ReturnMatchingJIRARequests()
       // List<int> MarvalIds = GetMarvalProjectsRequestIDs(httpRequest);
     //  string jiraResponseText;
        JObject parsedJiraResponse;
    bool isMatch = false;
    string pattern = @"\b\d+\b";


       Log.Information("Moving status of request");
         JsonSerializerSettings settings = new JsonSerializerSettings
    {
        ReferenceLoopHandling = ReferenceLoopHandling.Ignore
    };
       string targetStateName = httpRequest.QueryString["status"];
       Log.Information("Moving to status " + targetStateName);
     
       
  string requestBody;
    using (StreamReader reader = new StreamReader(httpRequest.InputStream, Encoding.UTF8))
   // using (var reader = new StreamReader(httpRequest.RequestBody, Encoding.UTF8))
    {
        requestBody = reader.ReadToEnd();
    }
     
    // var requestBody = new StreamReader(httpRequest.InputStream).ReadToEnd();
    Log.Information("Request body is " + requestBody);
    Log.Information("Request body in another format is " + JsonConvert.SerializeObject(requestBody));
    parsedJiraResponse = JObject.Parse(requestBody);
    dynamic jiRAResp = parsedJiraResponse;

    Log.Information("Request body parsed is " + parsedJiraResponse);
    Log.Information("Lookig for field " + this.CustomFieldId);

    // var MarvalRequestNum = data.issue.fields[this.CustomFieldId].Value;
    int[] marvalArray = ConvertStringToArray(jiRAResp.issue.fields[this.CustomFieldId].Value);
    Log.Information("Numbers are " + marvalArray);
    // isMatch = numbers.All(n => Regex.IsMatch(n.ToString(), pattern));
    // Get other details like headers
    // string headersJson = JsonConvert.SerializeObject(httpRequest.Headers, Formatting.Indented, settings);
    // Log.Information("Request headers are " + headersJson);

       
    // List<dynamic> MarvalIds = this.ReturnMatchingJIRARequestsForMoveStatus(httpRequest);
    // int[] marvalArray = MarvalIds.Select(item => (int)item).ToArray();
    // numbers
    // int[] marvalArray = MarvalIds.Select(item => (int)item).ToArray();

       foreach (int requestId in marvalArray)
        {
        Log.Information("Working through id in MoveMSMStatus " + requestId);
        string updatedTargetStateName = targetStateName.Replace("%20", " ");
        this.AddMsmNote(requestId, "JIRA requested to move to status " + updatedTargetStateName);
        var workflowInfo = GetRequestWorkflowId(requestId);
        var httpWebRequest = ApiHandler.BuildRequest(this.MSMBaseUrl + string.Format("/api/serviceDesk/operational/workflows/{0}", workflowInfo.WorkflowId), null, "GET");
        JObject requestWorkflowResponse = JObject.Parse(ApiHandler.ProcessRequest(httpWebRequest,  "Bearer " + this.MsmApiKey));
        WorkflowReadResponse response = requestWorkflowResponse["entity"].ToObject<WorkflowReadResponse>();
        Log.Information("Have object response2 in MoveMSMStatus " + response);
        Log.Information("startId is: {StatusId}, targetStateName is {targetStateName} ", workflowInfo.StatusId, targetStateName);
          string statesAsString = JsonConvert.SerializeObject(response.data.states, Formatting.Indented);
            var distinctObjects = response.data.states
            .Where(obj => obj.NextWorkflowStatusIds != null)
            .GroupBy(obj => obj.Id)
            .Select(group => group.First())
            .ToList();
        foreach (var obj in distinctObjects)
        {
           obj.NextWorkflowStatusIds = obj.NextWorkflowStatusIds
           .Where(id => distinctObjects.Any(o => o.Id == id))
           .ToList();
        }
        Log.Information("Target states distinct is " + JsonConvert.SerializeObject(distinctObjects, Formatting.Indented));
        List<int> path = GetPathToState2(distinctObjects, workflowInfo.StatusId, targetStateName);
        // List<int> path = [];
    
        if (path.Count > 0)
        {
             Log.Information("Path to " + targetStateName);
            foreach (int id in path)
            {
                Log.Information("Have id to go to " + id);
                Dictionary<string, object> workflowUpdate = new  Dictionary<string, object>();
                workflowUpdate["WorkflowStatusId"] = id;
                // jsonBody["UpdatedOn"] = (DateTime)requestIdResponse["entity"]["data"]["updatedOn"];
            
                var httpWebRequest4 = ApiHandler.BuildRequest(this.MSMBaseUrl + string.Format("/api/serviceDesk/integration/requests/{0}/partial", requestId), JsonHelper.ToJson(workflowUpdate), "PUT");
                Log.Information("Have response as " + httpWebRequest4);
                var moveStatusResponse = ApiHandler.ProcessRequest(httpWebRequest4, "Bearer " + this.MsmApiKey);
                Log.Information("Have response2 as " + moveStatusResponse);
                Log.Information("Path to state is " + id);
                // this.AddMsmNote(requestId, "JIRA plugin updated status to " + updatedTargetStateName);
            }
        }
        else
        {
            this.AddMsmNote(requestId, "JIRA status update failed: " + updatedTargetStateName + " is not a valid next state.");
            Log.Information("Target state not found in the workflow  " + targetStateName);
        }
     }
    }
static List<int> GetPathToState2(List<State> states, int startStateID, string targetStateName, List<List<int>> currBranches = null, int recurrNum = 0)
{
    Log.Information("Looking up state name " + targetStateName);
    targetStateName = Uri.UnescapeDataString(targetStateName);
     State targetState = states.Find(state => state.Name == targetStateName);
     if (targetState == null) {
          Log.Information("No target state");
            return  new List<int>();
     }
        int endStateID = targetState.Id;
        if (endStateID == startStateID) {
            Log.Information("State already at end state");
            return  new List<int>();
        }
    if (states.Find(state => state.Id == startStateID) == null || states.Find(endState => endState.Id == endStateID) == null)
    {
        return new List<int>();
        Log.Information("startStateID or end state could not be found");        // EXCEPTION
        // Handle workflow not containing start or end state
    }

    // Create initial branch
    if (currBranches == null || currBranches.Count == 0)
    {
        List<int> startList = new List<int>();
        startList.Add(startStateID);
        currBranches = new List<List<int>>();
        currBranches.Add(startList);
    }

    List<List<int>> newBranches =  new List<List<int>>();
    string json = JsonConvert.SerializeObject(newBranches, Formatting.Indented);
    string json2 = JsonConvert.SerializeObject(currBranches, Formatting.Indented);
    // string jsonstates = JsonConvert.SerializeObject(currBranches, Formatting.Indented);
        
    foreach (List<int> branch in currBranches)
    {
        int lastID = branch[branch.Count - 1]; // The last ID in this branch.
        Log.Information("Last id is "+ lastID);
        // Add a new branch to newBranches with the next ID or return if one of the new branches has the end state.
        foreach (int nextID in states.Find(state => state.Id == lastID).NextWorkflowStatusIds)
        {
            List<int> newBranch = new  List<int>(branch);
            newBranch.Add(nextID);
            
            if (nextID == endStateID)
            {
                return newBranch;
            }
            else
            {
                newBranches.Add(newBranch);
                string json2BR2 = JsonConvert.SerializeObject(newBranch, Formatting.Indented);
                string json2BR = JsonConvert.SerializeObject(newBranches, Formatting.Indented);
            }
        }
    }

    recurrNum++;
    if (recurrNum > 20)
    {
        return  new List<int>();
        Log.Information("Somethihng recursed...");
        // EXCEPTION
        // Handle endState being inaccessible/paths looping
    }
    return GetPathToState2(states,startStateID,targetStateName,newBranches,recurrNum);
    
}

private  List<dynamic> ReturnMatchingJIRARequestsForMoveStatus(HttpRequest httpRequestResponse) {
   Log.Information("Now finding matching JIRA requests for request with http response as " + httpRequestResponse); 
   Log.Information("Now finding matching JIRA requests for request number " + this.msmRequestNo);
        HttpWebRequest httpWebRequestJIRA = ApiHandler.BuildRequest(string.Format("{0}search?jql='{1}'~{2}", this.ApiBaseUrl, this.CustomFieldName, this.msmRequestNo), null, "GET", this.Proxy);
        string pattern = @"\b\d+\b";
        List<dynamic> matchingItems = new List<dynamic>();
        string jiraResponseText;
        JObject parsedJiraResponse;
        try
        {
            Log.Information("JIRA Credentials are "+ this.JiraCredentials );
            jiraResponseText = ApiHandler.ProcessRequest(httpWebRequestJIRA, "Basic " + this.JiraCredentials);
            parsedJiraResponse = JObject.Parse(jiraResponseText);
            bool isMatch = false;
            
            if (parsedJiraResponse["errorMessages"] != null) {
               
                matchingItems.Add(parsedJiraResponse);
                return matchingItems;
            } else {
            foreach (dynamic item in parsedJiraResponse["issues"])
            {

                int[] numbers = ConvertStringToArray(item.fields[this.CustomFieldId].Value);
                isMatch = numbers.All(n => Regex.IsMatch(n.ToString(), pattern));

                // isMatch = Regex.IsMatch(item.fields[this.CustomFieldId].Value, pattern);
                
                if (isMatch)
                {
                 
                    string convertedValue = ConvertArrayToString(numbers);
                    matchingItems.Add(item);
                }
                else
                {
                   
                }
            }
            }
            if (!isMatch)
            {
            
                //return matchingItems;
            }
        }
        catch (JsonReaderException jsonEx)
        {
            Log.Information("Error parsing JSON response: " + jsonEx);
        }
        catch (Exception ex)
        {
            Log.Information("An unexpected error occurred: " + ex);
        }

        return matchingItems;

}
    private  List<dynamic> ReturnMatchingJIRARequests()
    {
        Log.Information("Now finding matching JIRA requests for request number " + this.msmRequestNo);
        HttpWebRequest httpWebRequestJIRA = ApiHandler.BuildRequest(string.Format("{0}search?jql='{1}'~{2}", this.ApiBaseUrl, this.CustomFieldName, this.msmRequestNo), null, "GET", this.Proxy);
        string pattern = @"\b\d+\b";
        List<dynamic> matchingItems = new List<dynamic>();
        string jiraResponseText;
        JObject parsedJiraResponse;
        try
        {
            Log.Information("JIRA Credentials are "+ this.JiraCredentials );
            jiraResponseText = ApiHandler.ProcessRequest(httpWebRequestJIRA, "Basic " + this.JiraCredentials);
            parsedJiraResponse = JObject.Parse(jiraResponseText);
            bool isMatch = false;
            
            if (parsedJiraResponse["errorMessages"] != null) {
               
                matchingItems.Add(parsedJiraResponse);
                return matchingItems;
            } else {
            foreach (dynamic item in parsedJiraResponse["issues"])
            {

                int[] numbers = ConvertStringToArray(item.fields[this.CustomFieldId].Value);
                isMatch = numbers.All(n => Regex.IsMatch(n.ToString(), pattern));

                // isMatch = Regex.IsMatch(item.fields[this.CustomFieldId].Value, pattern);
                if (isMatch)
                {
                 
                    string convertedValue = ConvertArrayToString(numbers);
                    matchingItems.Add(item);
                }
                else
                {
                   
                }
            }
            }
            if (!isMatch)
            {
            
                //return matchingItems;
            }
        }
        catch (JsonReaderException jsonEx)
        {
            Log.Information("Error parsing JSON response: " + jsonEx);
        }
        catch (Exception ex)
        {
            Log.Information("An unexpected error occurred: " + ex);
        }

        return matchingItems;
    }

    private string LoadSummaryTemplate(HttpContext context)
    {
        return File.ReadAllText(context.Server.MapPath(string.Format("{0}/MarvalSoftware.Plugins.Jira.Summary.html", this.PluginRelativeBaseUrl)));
    }

    /// <summary>
    /// Build a summary preview of the jira issue to display in MSM
    /// </summary>
    /// <returns></returns>
    private string BuildPreview(HttpContext context, string issueString)
    {
        if (string.IsNullOrEmpty(issueString)) return string.Empty;
        var issueDetails = this.PopulateIssueDetails(issueString);
        var processedTemplate = this.PreProcessTemplateResourceStrings(this.LoadSummaryTemplate(context));
        string razorTemplate;
        using (var razor = new RazorHelper())
        {
            bool isError;
            razorTemplate = razor.Render(processedTemplate, issueDetails, out isError);
        }
        return razorTemplate;
    }

    private Dictionary<string, string> PopulateIssueDetails(string issueString)
    {
        var issue = JsonHelper.FromJson(issueString);
        var issueDetails = new Dictionary<string, string>();

        var issueType = issue.fields["issuetype"];
        issueDetails.Add("issueTypeIconUrl", Convert.ToString(issueType.iconUrl));
        issueDetails.Add("issueTypeName", Convert.ToString(issueType.name));

        var project = issue.fields["project"];
        issueDetails.Add("projectIconUrl", Convert.ToString(project.avatarUrls["32x32"]));
        issueDetails.Add("issueUrl", this.BaseUrl + string.Format("browse/{0}", issue.key));
        issueDetails.Add("summary", HttpUtility.HtmlEncode(Convert.ToString(issue.fields["summary"])));
        issueDetails.Add("issueProjectAndKey", string.Format("{0} / {1}", project.name, issue.key));

        var status = issue.fields["status"];
        var statusCategory = status.statusCategory;
        issueDetails.Add("statusName", Convert.ToString(status.name));
        issueDetails.Add("statusCategoryBackgroundColor", Convert.ToString(statusCategory.colorName));

        var priority = issue.fields["priority"];
        issueDetails.Add("priorityName", Convert.ToString(priority.name));
        issueDetails.Add("priorityIconUrl", Convert.ToString(priority.iconUrl));

        var resolution = issue.fields["resolution"];
        issueDetails.Add("resolution", resolution != null ? Convert.ToString(resolution.name) : "Unresolved");

        var affectedVersions = (JArray)issue.fields["versions"];
        issueDetails.Add("affectsVersions", affectedVersions.Any() ? string.Join(",", affectedVersions.Select(av => ((dynamic)av).name)) : "None");

        var fixVersions = (JArray)issue.fields["fixVersions"];
        issueDetails.Add("fixVersions", fixVersions.Any() ? string.Join(",", fixVersions.Select(fv => ((dynamic)fv).name)) : "None");

        var components = (JArray)issue.fields["components"];
        issueDetails.Add("components", components.Any() ? string.Join(",", components.Select(c => ((dynamic)c).name)) : "None");

        var labels = (JArray)issue.fields["labels"];
        issueDetails.Add("labels", labels.Any() ? string.Join(",", labels.Select(c => ((dynamic)c).Value)) : "None");
        issueDetails.Add("storyPoints", Convert.ToString(issue.fields["customfield_10006"]));

        var assignee = issue.fields["assignee"];
        issueDetails.Add("assigneeName", assignee != null ? Convert.ToString(assignee.displayName) : "Unassigned");
        issueDetails.Add("assigneeIconUrl", assignee != null ? Convert.ToString(assignee.avatarUrls["16x16"]) : string.Empty);

        var reporter = issue.fields["reporter"];
        issueDetails.Add("reporterName", reporter != null ? Convert.ToString(reporter.displayName) : string.Empty);
        issueDetails.Add("reporterIconUrl", reporter != null ? Convert.ToString(reporter.avatarUrls["16x16"]) : string.Empty);

        DateTime createdDate;
        issueDetails.Add("created", string.Empty);
        if (DateTime.TryParse(Convert.ToString(issue.fields["created"]), out createdDate))
        {
            issueDetails["created"] = this.GetRelativeTime(createdDate);
        }

        DateTime updatedDate;
        issueDetails.Add("updated", string.Empty);
        if (DateTime.TryParse(Convert.ToString(issue.fields["updated"]), out updatedDate))
        {
            issueDetails["updated"] = this.GetRelativeTime(updatedDate);
        }

        issueDetails.Add("description", this.ProcessJiraDescription(issue));
        issueDetails.Add("msmLink", string.Empty);
        issueDetails.Add("msmLinkName", string.Empty);
        issueDetails.Add("requestTypeIconUrl", string.Empty);

        if (issue.fields[this.CustomFieldId] == null) return issueDetails;
        var requestId = Convert.ToString(issue.fields[this.CustomFieldId]);
        var msmResponse = string.Empty;

        try
        {
            msmResponse = ApiHandler.ProcessRequest(ApiHandler.BuildRequest(this.MSMBaseUrl + string.Format("/api/serviceDesk/operational/requests/{0}", requestId), null, "GET", this.Proxy), ApiHandler.GetEncodedCredentials(this.MsmApiKey));
            var requestResponse = JObject.Parse(msmResponse);
            issueDetails["msmLinkName"] = string.Format("{0}-{1} {2}", requestResponse["entity"]["data"]["type"]["acronym"], requestResponse["entity"]["data"]["number"], requestResponse["entity"]["data"]["description"]);
            issueDetails["msmLink"] = string.Format("{0}{1}/RFP/Forms/Request.aspx?id={2}", HttpContext.Current.Request.Url.GetLeftPart(UriPartial.Authority), MarvalSoftware.UI.WebUI.ServiceDesk.WebHelper.ApplicationPath, requestId);
            issueDetails["requestTypeIconUrl"] = this.GetRequestBaseTypeIconUrl(Convert.ToInt32(requestResponse["entity"]["data"]["type"]["baseTypeId"]));
        }
        catch (Exception ex)
        {
            issueDetails["msmLinkName"] = null;
        }

        return issueDetails;
    }

    private string ProcessJiraDescription(dynamic issue)
    {
        var description = Convert.ToString(issue.fields["description"]);
        if (string.IsNullOrEmpty(description)) return description;

        description = Convert.ToString(this.InvokeCustomPluginStaticTypeMember("WikiNetParser.dll", "WikiNetParser.WikiProvider", "ConvertToHtml", new[] { description }));
        foreach (System.Text.RegularExpressions.Match match in System.Text.RegularExpressions.Regex.Matches(description, @"!(.*)!"))
        {
            if (match.Groups.Count <= 1) continue;

            var filename = match.Groups[1].Value;
            var dimension = string.Empty;
            var dimensionMatch = System.Text.RegularExpressions.Regex.Match(filename, @"(.*)\|width=([0-9]*),height=([0-9]*)");
            if (dimensionMatch.Success && dimensionMatch.Groups.Count > 2)
            {
                filename = dimensionMatch.Groups[1].Value;
                dimension = string.Form
