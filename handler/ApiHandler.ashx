<%@ WebHandler Language = "C#" Class="ApiHandler" %>

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

    public class fullResponse
    {
        public int responseCode { get; set; }//res code
        public string responseDes { get; set; } //res desc
        public string responseBody { get; set; } //res body
    }

    public class Entity
    {
        public EntityData data { get; set; }
    }

    public class WorkflowReadResponse
    {
        public EntityData data { get; set; }
    }
    //properties'

    private string userCustomField
    {
        get
        {
            return this.GlobalSettings["@@CUSTOMATTRIBUTE"];
        }
    }

    private string newApiKey
    {
        get
        {
            return this.GlobalSettings["@@APIKEY"];
        }
    }
    private string CustomFieldName
    {
        get
        {
            return this.GlobalSettings["@@JIRACustomFieldName"];
        }
    }

    private string openprojectapikey
    {
        get
        {
            return this.GlobalSettings["@@OpenProjectAPIKey"];
        }
    }

    private string openprojectendpointurl
    {
        get
        {
            return this.GlobalSettings["@@OpenProjectAPIEndpointUrl"];
        }
    }

    private string openprojectworkspacename
    {
        get
        {
            return this.GlobalSettings["@@OpenProjectWorkspaceName"];
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

    private string BaseUrl
    {
        get
        {
            return "https://graph.openproject.com/";
        }
    }
    private string ApiBaseUrl
    {
        get
        {
            return "https://graph.openproject.com/";
        }
    }
    private string GraphApiBaseUrl
    {
        get
        {
            return "https://graph.openproject.com/";
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
    private string CloseStatus
    {

        get
        {
            return this.GlobalSettings["@@ClosureStatus"];

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

    private string resContent;


    private string JIRAFieldType { get; set; }
    private string JIRAFieldID { get; set; }
    private string JiraIssueNo { get; set; }

    private string JiraSummary { get; set; }

    private string JiraType { get; set; }
    public string MarvalProjectName { get; set; }

    private string JiraProject { get; set; }

    private string JiraReporter { get; set; }
    private string jsonProjectData { get; set; }

    private string AttachmentIds { get; set; }

    private string MsmContactEmail { get; set; }

    private string IssueUrl { get; set; }

    //fields
    private int msmRequestNo;
    private int msmRequestId;
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

        if (httpRequest.HttpMethod == "POST" && httpRequest.Params["action"] == "CreateOpenProjectProject")
        {
            using (StreamReader reader = new StreamReader(httpRequest.InputStream))
            {
                string postData = reader.ReadToEnd();
                this.jsonProjectData = postData;
                try
                {
                    JObject parsedpostDataResponse = JObject.Parse(postData);
                    var description = parsedpostDataResponse["title"].ToString() ?? string.Empty;
                    // var project = parsedpostDataResponse["project"].ToString() ?? string.Empty;
                    //  var RequestTypeAcronym = parsedpostDataResponse["requesttypeacronym"].ToString() ?? string.Empty;
                    // var _requestNumber = parsedpostDataResponse["requestnumber"].ToString() ?? string.Empty;
                    // Process description as needed
                }
                catch (Exception ex)
                {
                    Log.Information("An unexpected error occurred: " + ex);
                }
            }
        }
        int.TryParse(httpRequest.Params["requestNumber"], out this.msmRequestNo);
        int.TryParse(httpRequest.Params["requestId"], out this.msmRequestId);

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

        string apiKey = newApiKey;
        string encodedAuth = Convert.ToBase64String(Encoding.ASCII.GetBytes("apikey:"+apiKey));

        string reqid = context.Request.QueryString["reqId"];
        string projectId = "";
        string filter = "";

        switch (action)
        {
            case "PreRequisiteCheck":
                context.Response.Write(this.PreRequisiteCheck());
                break;
            case "getAllWorkPackages":
                httpWebRequest = ApiHandler.BuildRequest("http://localhost:8080/api/v3/projects/"+reqid+"/work_packages");

                httpWebRequest.Headers["Authorization"] = "Basic " + encodedAuth;
                var responseContent3 = this.ProcessRequest2(httpWebRequest);

                context.Response.Write(responseContent3);

                break;
            case "getCustomField":
                context.Response.Write(userCustomField); //return custom field
                break;
            //should do a link project
            //then in frontend we can check if customfield2 already has stuff if in it, if it does we do append and new case link project append, if not we go tro unlink project
            case "unlinkProject": //technically it is still link project
                string cInput = "0"; //cannot be blank, need to set it as something
                //string customField2Value = (context.Request.QueryString["customField2"]);
                //string reqIdValue = context.Request.QueryString["reqId"];
                if (!string.IsNullOrEmpty(context.Request.QueryString["reqId"]) && !string.IsNullOrEmpty(context.Request.QueryString["customField2"]))
                {//meaning that we are linking
                    string customField2Value = (context.Request.QueryString["customField2"]);
                    string reqIdValue = context.Request.QueryString["reqId"];
                    string link =  context.Request.QueryString["link"];

                    if (!customField2Value.Split(',').Contains(reqIdValue) && link != "FALSE")
                    {
                        cInput = customField2Value + "," + reqIdValue;
                    }
                    else if(link == "FALSE")
                    {
                        var parts = customField2Value
                        .Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries)
                        .Select(p => p.Trim())
                        .Where(p => p != reqIdValue) // remove the one we're unlinking
                        .ToList();

                        //     cInput = string.Join(",", parts); // recombine the list

                        cInput = parts.Count == 0 ? "0" : string.Join(",", parts);
                    }
                    //cInput = context.Request.QueryString["reqId"];
                }else if (!string.IsNullOrEmpty(context.Request.QueryString["reqId"]))
                {
                    cInput = context.Request.QueryString["reqId"]; //means customfield2 is currently blank, means we simply set it to the request id to link them
                }

                string apiKey3 = "1f389038cf762946cedf25f8cb4c204730814c764200bd27dbb0dceb521fc0a6";
                string encodedAuth3 = Convert.ToBase64String(Encoding.ASCII.GetBytes("apikey:"+apiKey3));

                //so if we are linking, attribute = req id, if unlinking we are settting attribute to be blank!
                var myPayload3 = new
                {
                    userCustomField = cInput
                };

                string payloadJson3 = JsonConvert.SerializeObject(myPayload3);
                projectId = context.Request.QueryString["id"];

                httpWebRequest = ApiHandler.BuildRequest("http://localhost:8080/api/v3/projects/" + projectId, payloadJson3, "PATCH");
                httpWebRequest.Headers["Authorization"] = "Basic " + encodedAuth3;
                httpWebRequest.ContentType = "application/json";
                string ex3 = this.ProcessRequest2(httpWebRequest);
                context.Response.Write("{}");


                break;
            case "getAllProjects": //this actually gets all projects linked to the request id passed, can use this to get id
                string identifier = "";
                if (!string.IsNullOrEmpty(context.Request.QueryString["identifier"]))//we have an identifier so we want to filter with identifier
                {
                    filter = "name_and_identifier";
                    identifier = context.Request.QueryString["identifier"];
                }
                else
                {
                    filter = userCustomField;
                    identifier = context.Request.QueryString["reqId"];
                }
                httpWebRequest = ApiHandler.BuildRequest("http://localhost:8080/api/v3/projects?filters=[{\""+filter+"\":{\"operator\":\"=\",\"values\":[\"" + identifier + "\"]}}]");

                httpWebRequest.Headers["Authorization"] = "Basic " + encodedAuth;
                var responseContent = this.ProcessRequest2(httpWebRequest);
                context.Response.Write(responseContent);

                break;
            case "getAllProjects2": //gets all projects
                string identifier2 = "";
                if (!string.IsNullOrEmpty(context.Request.QueryString["identifier"]))//we have an identifier so we want to filter with identifier
                {
                    filter = "name_and_identifier";
                    identifier2 = context.Request.QueryString["identifier"];
                }
                else
                {
                    filter = "customField3";
                    identifier2 = context.Request.QueryString["reqId"];
                }
                httpWebRequest = ApiHandler.BuildRequest("http://localhost:8080/api/v3/projects");

                httpWebRequest.Headers["Authorization"] = "Basic " + encodedAuth;
                var responseContent4 = this.ProcessRequest2(httpWebRequest);
                context.Response.Write(responseContent4);

                break;
            case "getMarvalProjectTemplates":
                httpWebRequest = ApiHandler.BuildRequest("http://localhost:8080/api/v3/projects?filters=[{\"user_action\":{\"operator\":\"=\",\"values\":[\"projects/copy\"]}},{\"templated\":{\"operator\":\"=\",\"values\":[\"t\"]}}]");
                httpWebRequest.Headers["Authorization"] = "Basic " + encodedAuth;
                var responseContent2 = this.ProcessRequest2(httpWebRequest);
                context.Response.Write(responseContent2); //should use other var name

                break;
            case "createProject":
                string requestBody;
                string curUrl;
                string reqId = context.Request.QueryString["reqId"];

                using(var reader = new StreamReader(context.Request.InputStream))
                {
                    requestBody = reader.ReadToEnd();
                }

                string apiKey2 = "1f389038cf762946cedf25f8cb4c204730814c764200bd27dbb0dceb521fc0a6";
                string encodedAuth2 = Convert.ToBase64String(Encoding.ASCII.GetBytes("apikey:"+apiKey2));

                dynamic parsedBody = JsonConvert.DeserializeObject(requestBody);

                //var myPayload = new
                //{
                //    name = parsedBody.name, //get custom field 1 from global settings
                //    [userCustomField] = reqId, //need to set these as blank when we are creating a new project, 
                //    customField3 = "0" //for new users they only need one customfield
                //};
                //string payloadJson = JsonConvert.SerializeObject(myPayload);
                var myPayload = new Dictionary<string, object> //hash map, object can be different types
                    {
                        { "name", parsedBody.name },
                        { userCustomField, reqId }, // dynamic key
                        { "customField3", "0" }
                    };

                string payloadJson = JsonConvert.SerializeObject(myPayload);

                if (parsedBody.copy == true)
                {
                    curUrl = "http://localhost:8080/api/v3/projects/" + parsedBody.id + "/copy";
                }
                else
                {
                    curUrl = "http://localhost:8080/api/v3/projects";
                }
                Log.Information("payload is" + myPayload);
                httpWebRequest = ApiHandler.BuildRequest(curUrl, payloadJson, "POST");
                httpWebRequest.Headers["Authorization"] = "Basic " + encodedAuth2;
                httpWebRequest.ContentType = "application/json";
                string ex = this.ProcessRequest2(httpWebRequest);
                context.Response.Write("{ \"success\": \"successfully created\"}");


                break;
            case "GetOpenProjectProjects":
                //var OpenProjectProjectsResponse = this.GetOpenProjectProjects();
                //Log.Information("Have response from get projects as " + OpenProjectProjectsResponse);
                //dynamic OpenProjectProjectsresponseObject = JsonConvert.DeserializeObject(OpenProjectProjectsResponse);
                //OpenProjectProjectsresponseObject.htmlPrefix = this.openprojectworkspacename;
                //string modifiedJson = JsonConvert.SerializeObject(OpenProjectProjectsresponseObject);
                //context.Response.Write(modifiedJson);
                context.Response.Write(" ");
                break;
            case "GetProjectTemplates":
                //var OpenProjectProjectTemplatesResponse = this.GetOpenProjectProjectTemplates();
                //Log.Information("Have response from get projects as " + OpenProjectProjectTemplatesResponse);

                //context.Response.Write(OpenProjectProjectTemplatesResponse);
                context.Response.Write("");
                break;
            case "CompleteProject":

                this.MoveMSMStatusComplete(context.Request, CloseStatus);

                context.Response.Write("Response from CompleteProject");
                break;
            case "MoveStatusComplete":

                Log.Information("Running Integration Endpoint MoveStatusComplete");

                this.MoveMSMStatusComplete(context.Request, CloseStatus);
                // this.AddMsmNote(this.msmRequestId,"Marval request Completed from OpenProject");
                context.Response.Write("Response from MoveMSMStatusComplete");
                break;
            case "MoveStatus2":

                Log.Information("Running Integration Endpoint MoveStatusComplete");

                this.MoveMSMStatusComplete(context.Request, CloseStatus);
                // this.AddMsmNote(this.msmRequestId,"Marval request Completed from OpenProject");
                context.Response.Write("Response from MoveMSMStatusComplete");
                break;
            case "EndpointPingCheck":
                //var PingResult = PingCheck();
                //Log.Information("Have response from ping check as " + PingResult);
                //context.Response.Write(PingResult);
                context.Response.Write(" ");
                break;
            case "LinkOpenProjectProject":
                context.Response.Write(this.UpdateOpenProjectIssue(this.msmRequestNo));

                break;
            case "CreateOpenProjectProject":
                dynamic OpenProjectProjectsSendObject = JsonConvert.DeserializeObject(jsonProjectData);
                int customerid = OpenProjectProjectsSendObject.customer.id;
                int trackerid = OpenProjectProjectsSendObject.tracker.id;
                int assigneeid = OpenProjectProjectsSendObject.assignee.id;
                int customercontactid = OpenProjectProjectsSendObject.customercontact.id;
                string TrackerType = GetOUType(trackerid);
                string CustomerType = GetOUType(customerid);
                string CustomerContactType = GetOUType(customercontactid);
                string AssigneeType = GetOUType(assigneeid);
                OpenProjectProjectsSendObject.customer.type = CustomerType;
                OpenProjectProjectsSendObject.customercontact.type = CustomerContactType;
                OpenProjectProjectsSendObject.tracker.type = TrackerType;
                OpenProjectProjectsSendObject.assignee.type = AssigneeType;
                string modifiedJsonCreate = JsonConvert.SerializeObject(OpenProjectProjectsSendObject);

                if (CustomerContactType == "OrganisationalUnit")
                {
                    context.Response.Write("{ \"errors\": \"Cannot create project, please set contact as an individual person, not organisational unit\"}");
                }
                else
                {
                    var createProjectResponse = this.CreateOpenProjectProject(modifiedJsonCreate);
                    context.Response.Write(createProjectResponse);
                }

                break;
            case "UnlinkMarvalProjectsIssue":

                context.Response.Write(this.UpdateOpenProjectIssue(0));
                break;
            case "MoveStatus":
                this.MoveMsmStatus(context.Request);
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
        }
    }
    private string GetOUType(int OUid)
    {

        var msmResponse = ApiHandler.ProcessRequest(ApiHandler.BuildRequest(this.MSMBaseUrl + string.Format("/api/serviceDesk/integration/organisationalUnits/{0}", OUid), null, "GET"), "Bearer " + this.MsmApiKey);

        Log.Information("Have response from GetOUTType as " + msmResponse);
        dynamic OUResponseObj = JsonConvert.DeserializeObject(msmResponse);
        // dynamic requestResponse = JObject.Parse(msmResponse);

        return OUResponseObj.entity.data.type.name;
    }
    private int[] ConvertStringToArray(string input)
    {
        int[] numbers = Array.Empty<int>();
        if (string.IsNullOrEmpty(input))
        {
            return numbers;
        }
        // Split the input string by commas and remove any surrounding quotes
        string[] numberStrings = input.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries).Select(s => s.Trim('\"')).ToArray();
        // Convert the string array to an integer array
        numbers = Array.ConvertAll(numberStrings, int.Parse);

        return numbers;
    }

    private string ProcessRequest2(HttpWebRequest request)
    {
        fullResponse myRes = new fullResponse();
        try
        {
            //var resStatus = ((HttpWebResponse)request.WebResponse).StatusCode;
            //request.Headers.Add("Authorization", "Bearer " + this.UserAPIKey);
            HttpWebResponse response = request.GetResponse() as HttpWebResponse;
            var res = "";
            var resStatus = ((HttpStatusCode)response.StatusCode);
            using (StreamReader reader = new StreamReader(response.GetResponseStream()))
            {
                res = reader.ReadToEnd();
            }
            HttpContext.Current.Response.StatusCode = (int)resStatus;
            HttpContext.Current.Response.ContentType = "application/json";
            HttpContext.Current.Response.Write(res);
            HttpContext.Current.Response.End();
            return null;

        }
        catch (WebException webEx)
        {
            var result = "";
            var errStatus = ((HttpWebResponse)webEx.Response).StatusCode;
            var errResp = webEx.Response;

            //myRes.responseCode = Int32.Parse(errStatus.ToString());
            Log.Information("err is" + errStatus.ToString());
            myRes.responseDes = ((HttpWebResponse)errResp).StatusDescription;
            var res = "";
            using (StreamReader reader = new StreamReader(errResp.GetResponseStream()))
            {
                res = reader.ReadToEnd();
            }
            //myRes.responseBody = res;
            HttpContext.Current.Response.StatusCode = (int)errStatus;
            HttpContext.Current.Response.ContentType = "application/json";
            HttpContext.Current.Response.Write(res);
            HttpContext.Current.Response.End();

            return null;

        }
    }
    private string ConvertArrayToString(int[] numbers)
    {
        // Convert the integer array to a string with comma-separated values
        string result = string.Join(",", numbers);
        // Add quotes around each number
        result = string.Join(",", numbers.Select(n => string.Format("\"{0}\"", n)));
        return result;
    }
    private string CreateOpenProjectProject(string jsonData)
    {
        // https://graph.openproject.com/marvalIntegration.cfm
        Log.Information("Now in CreateOpenProjectProject");
        Log.Information("Creation of Marval Projects project is sending payload " + jsonData);
        var openProjectIntegrationAddress = string.IsNullOrEmpty(openprojectendpointurl) ? "https://graph.openproject.com/marvalIntegration.cfm" : openprojectendpointurl;
        var httpWebRequest = ApiHandler.BuildRequest(openProjectIntegrationAddress, jsonData, "POST");
        var response = ApiHandler.ProcessRequest(httpWebRequest, this.openprojectapikey);
        return response;

    }
    private string GetOpenProjectProjects()
    {
        //        var queryString = "{ projects(input: {where: {marvalid: {EQ: " + this.msmRequestId + "}}}) { itemsActive itemsCompleted id title description status startdate duedate number completedate clientcontact { firstname lastname } tasks { id name startdate duedate completedate } tags { id name } }}";
        var queryString = "{ projects(input: {where: {marvalid: {EQ: " + this.msmRequestId + "}}}) { itemsActive itemsCompleted id title description status startdate duedate number completedate clientcontact { firstname lastname } tags { id name } projectworkstages(input:{active:{EQ:true}}) {id name} }}";
        dynamic jobject = JObject.FromObject(new
        {
            query = queryString

        });

        var httpWebRequest = ApiHandler.BuildRequest(this.GraphApiBaseUrl, jobject.ToString(), "POST");
        var response = ApiHandler.ProcessRequest(httpWebRequest, this.openprojectapikey);

        // dynamic MPObject = JsonConvert.DeserializeObject(response);
        // OpenProjectProjectsresponseObject.htmlPrefix = this.openprojectworkspacename;
        return response;

    }
    private string GetOpenProjectProjectTemplates()
    {
        var queryString = "{ projects (input: {where: {template: {EQ: true},activeworkstate: {EQ: active},isclassic: {EQ: false}}}) { id isclassic title }}";
        dynamic jobject = JObject.FromObject(new
        {
            query = queryString

        });

        var httpWebRequest = ApiHandler.BuildRequest(this.GraphApiBaseUrl, jobject.ToString(), "POST");
        var response = ApiHandler.ProcessRequest(httpWebRequest, this.openprojectapikey);

        return response;

    }
    private string LoadSummaryTemplate(HttpContext context)
    {
        return File.ReadAllText(context.Server.MapPath(string.Format("{0}/MarvalSoftware.Plugins.OpenProject.Summary.html", this.PluginRelativeBaseUrl)));
    }

    /// <summary>
    /// Build a summary preview of the Prowokflow Project to display in MSM
    /// </summary>
    /// <returns></returns>
    private string BuildPreview(HttpContext context, string issueString)
    {
        if (string.IsNullOrEmpty(issueString)) return string.Empty;
        Log.Information("Have issues string as " + issueString);
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

    private string PingCheck()
    {
        dynamic jobject = JObject.FromObject(new
        {
            query = "{ projects { id }}"

        });

        var httpWebRequest = ApiHandler.BuildRequest(this.GraphApiBaseUrl, jobject.ToString(), "POST");
        var response = ApiHandler.ProcessRequest(httpWebRequest, this.openprojectapikey);
        return response;
    }

    private Dictionary<string, string> PopulateIssueDetails(string issueString)
    {
        var issue = JsonHelper.FromJson(issueString);
        Log.Information("Have issue string as " + issueString);
        var issueDetails = new Dictionary<string, string>();
        Log.Information("Issues string is " + issue);

        var project = issue.data.projects[0];
        Log.Information("Have project as " + project);
        Log.Information("Have project description as " + project.description);

        issueDetails.Add("summary", HttpUtility.HtmlEncode(Convert.ToString(project.title)));


        DateTime createdDate;

        issueDetails.Add("workspacename", Convert.ToString(this.openprojectworkspacename));
        issueDetails.Add("description", Convert.ToString(project.description));
        issueDetails.Add("id", Convert.ToString(project.id));
        issueDetails.Add("title", Convert.ToString(project.title));
        issueDetails.Add("number", Convert.ToString(project.number));
        issueDetails.Add("status", Convert.ToString(project.status));
        issueDetails.Add("startdate", project.startdate != null ? Convert.ToString(project.startdate) : string.Empty);
        issueDetails.Add("duedate", project.duedate != null ? Convert.ToString(project.duedate) : string.Empty);
        issueDetails.Add("completeddate", project.completeddate != null ? Convert.ToString(project.completeddate) : string.Empty);
        issueDetails.Add("firstname", Convert.ToString(project.clientcontact.firstname));
        issueDetails.Add("lastname", Convert.ToString(project.clientcontact.lastname));
        Log.Information("Issue info is " + JsonHelper.ToJson(issueDetails));

        var requestId = this.msmRequestId;
        var msmResponse = string.Empty;

        try
        {
            msmResponse = ApiHandler.ProcessRequest(ApiHandler.BuildRequest(this.MSMBaseUrl + string.Format("/api/serviceDesk/operational/requests/{0}", requestId), null, "GET"), ApiHandler.GetEncodedCredentials(this.MsmApiKey));
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

    private string GetRequestBaseTypeIconUrl(int requestBaseType)
    {
        var baseRequestType = (MarvalSoftware.ServiceDesk.ServiceSupport.BaseRequestTypes)requestBaseType;
        string icon = baseRequestType.ToString().ToLower();
        if (icon == "changerequest")
        {
            icon = "change";
        }
        return string.Format("{0}{1}/Assets/Skins/{2}/Icons/{3}_32.png", HttpContext.Current.Request.Url.GetLeftPart(UriPartial.Authority), MarvalSoftware.UI.WebUI.ServiceDesk.WebHelper.ApplicationPath, MarvalSoftware.UI.WebUI.Style.StyleSheetManager.Skin, icon);
    }

    /// <summary>
    /// Gets attachment DTOs from array of attachment Ids
    /// </summary>   
    /// <param name="attachmentIds"></param>
    /// <returns>A list of attachment DTOs</returns>
    public List<AttachmentViewInfo> GetAttachmentDtOs(int[] attachmentIds)
    {
        var attachmentFacade = new RequestManagementFacade();
        return attachmentIds.Select(attachment => attachmentFacade.ViewAnAttachment(attachment)).ToList();
    }

    /// <summary>
    /// Link attachments to specified Jira issue.
    /// </summary>
    /// <param name="attachments"></param>
    /// <param name="issueKey"></param>
    /// <returns>The result of attempting to post the attachment data.</returns>
    public string PostAttachments(List<AttachmentViewInfo> attachments, string issueKey)
    {
        var boundary = string.Format("----------{0:N}", Guid.NewGuid());
        var content = new MemoryStream();
        var writer = new StreamWriter(content);
        var result = HttpStatusCode.OK.ToString();

        foreach (var attachment in attachments)
        {
            var data = attachment.Content;
            writer.WriteLine("--{0}", boundary);
            writer.WriteLine("Content-Disposition: form-data; name=\"file\"; filename=\"{0}\"", attachment.Name);
            writer.WriteLine("Content-Type: " + attachment.ContentType);
            writer.WriteLine();
            writer.Flush();
            content.Write(data, 0, data.Length);
            writer.WriteLine();
        }
        writer.WriteLine("--" + boundary + "--");
        writer.Flush();
        content.Seek(0, SeekOrigin.Begin);

        HttpWebResponse response;
        HttpWebRequest request = WebRequest.Create(new UriBuilder(this.ApiBaseUrl + "issue/" + issueKey + "/attachments").Uri) as HttpWebRequest;
        request.Method = "POST";
        request.ContentType = string.Format("multipart/form-data; boundary={0}", boundary);
        request.Headers.Add("Authorization", "Basic " + this.JiraCredentials);
        request.Headers.Add("X-Atlassian-Token", "nocheck");
        request.KeepAlive = true;
        request.ContentLength = content.Length;

        using (Stream requestStream = request.GetRequestStream())
        {
            content.CopyTo(requestStream);
        }

        using (response = request.GetResponse() as HttpWebResponse)
        {
            if (response.StatusCode != HttpStatusCode.OK)
            {
                result = response.StatusCode.ToString();
            }
        }
        return result;
    }


    /// <summary>
    /// Update Jira Issue
    /// </summary>
    /// <param name="value">Value to update custom field in JIRA with</param>
    /// <returns>Process Response</returns>
    private string UpdateOpenProjectIssue(int? value)
    {
        HttpWebRequest httpWebRequestJIRA;

        dynamic jobjectS = JObject.FromObject(new
        {
            query = "mutation UpdateProject($input: UpdateProjectInput) { updateProject(input: $input) { id marvalid } }",
            variables = new
            {
                input = new
                {
                    id = this.JiraIssueNo,
                    marvalid = value
                }
            }
        });

        var httpWebRequest2 = ApiHandler.BuildRequest(this.GraphApiBaseUrl, jobjectS.ToString(), "POST");
        var response = JObject.Parse(ApiHandler.ProcessRequest(httpWebRequest2, this.openprojectapikey));
        return response.ToString();

    }

    static object[] ProcessArray(Array array)
    {
        List<object> processedArray = new List<object>();
        foreach (var item in array)
        {
            if (item is string || item is int || item is double || item is bool)
            {
                processedArray.Add(item);
            }
            else
            {
                try
                {
                    processedArray.Add(item.ToString());
                }
                catch (Exception ex)
                {

                }
            }
        }
        return processedArray.ToArray();
    }

    static Dictionary<string, object> GetFormFields(dynamic form)
    {
        Dictionary<string, object> fields = new Dictionary<string, object>();

        foreach (dynamic fieldset in form.fieldsets)
        {
            foreach (dynamic field in fieldset.fields)
            {
                string fieldName = field.name;
                Log.Information("Going through name " + fieldName);
                object fieldValue = field.value;

                // Handle different types and convert them to object
                try
                {
                    if (fieldValue is string || fieldValue is int || fieldValue is double || fieldValue is bool && fieldName != "RelatedConfigurationItemIds")
                    {
                        fields[fieldName] = fieldValue;
                    }
                    else if (fieldName != "RelatedConfigurationItemIds" && fieldValue.ToString().StartsWith("[") && fieldValue.ToString().EndsWith("]"))
                    {

                        string[] elements = fieldValue.ToString().Trim('[', ']').Split(',');
                        List<object> arrayValues = new List<object>();
                        foreach (var element in elements)
                        {
                            int result = Int32.Parse(element);
                            arrayValues.Add(result);
                        }

                        fields[fieldName] = arrayValues.ToArray();
                    }
                    else
                    {
                        try
                        {
                            fields[fieldName] = fieldValue.ToString();
                        }
                        catch (Exception ex)
                        {
                            Log.Information("Error assigning field value to field name " + ex);
                        }
                    }
                }
                catch (Exception ex)
                {
                    Log.Information("Error building array " + ex);
                }

            }
        }

        return fields;
    }
    public static dynamic GetForm(string formName, dynamic response)
    {
        foreach (var form in response.forms)
        {
            if (form.name == formName)
            {
                return form;
            }
        }
        return null;
    }
    private void MoveMsmStatusMP(HttpRequest httpRequest)
    {
        // int requestNumbers;
        List<int> numbersList = new List<int>();
        var json = new StreamReader(httpRequest.InputStream).ReadToEnd();

        dynamic data = JObject.Parse(json);
        Log.Information("Have json from openproject in MoveMsmStatusMP as " + json);
        var MarvalProjectsId = data.id;
        // Log.Information("Have Marval Projects ID as " + MarvalProjectsId);
        var queryString = "{  projects(input: {where: {id: {EQ: " + MarvalProjectsId + " }}}) {    marvalid    }}";
        dynamic jobjectS = JObject.FromObject(new
        {
            query = queryString

        });

        var httpWebRequest = ApiHandler.BuildRequest(this.GraphApiBaseUrl, jobjectS.ToString(), "POST");
        var response = JObject.Parse(ApiHandler.ProcessRequest(httpWebRequest, this.openprojectapikey));
        int MarvaID = response["data"]["projects"][0]["marvalid"];
        //Log.Information("MarvalID is " + MarvaID); 

        numbersList.Add(MarvaID);
        int[] numbersArray = numbersList.ToArray();
        foreach (int requestId in numbersArray)
        {

            Log.Information("Running MoveMSMStatusMP for requestID " + requestId);
            Log.Information("Base URL is " + this.MSMBaseUrl);
            Log.Information("API Key is " + this.MsmApiKey);

            var httpWebRequest2 = ApiHandler.BuildRequest(this.MSMBaseUrl + string.Format("/api/serviceDesk/operational/requests/{0}", requestId), null, "GET");
            var requestIdResponse = JObject.Parse(ApiHandler.ProcessRequest(httpWebRequest2, "Bearer " + this.MsmApiKey));

            var workflowId = requestIdResponse["entity"]["data"]["requestStatus"]["workflowStatus"]["workflow"]["id"];

            var formDetail = GetForm("moveStatus", requestIdResponse);
            Dictionary<string, object> jsonBody = GetFormFields(formDetail);

            var httpWebRequest3 = ApiHandler.BuildRequest(this.MSMBaseUrl + string.Format("/api/serviceDesk/operational/workflows/{0}/nextStates?requestId={1}&namePredicate=equals({2})", workflowId, requestId, "Implement"), null, "GET");
            var requestWorkflowResponse = JObject.Parse(ApiHandler.ProcessRequest(httpWebRequest3, "Bearer " + this.MsmApiKey));
            Log.Information("Have response from getting workflow information as " + requestWorkflowResponse);
            var workflowResponseItems = (IList<JToken>)requestWorkflowResponse["collection"]["items"];
            if (workflowResponseItems.Count > 0)
            {
                dynamic msmPutRequest = new ExpandoObject();
                msmPutRequest.WorkflowStatusId = workflowResponseItems[0]["entity"]["data"]["id"];
                msmPutRequest.UpdatedOn = (DateTime)requestIdResponse["entity"]["data"]["updatedOn"];
                var WorkflowStatusId = workflowResponseItems[0]["entity"]["data"]["id"].ToString();
                var UpdatedOn = requestIdResponse["entity"]["data"]["updatedOn"].ToString();
                jsonBody["WorkflowStatusId"] = WorkflowStatusId;
                jsonBody["UpdatedOn"] = (DateTime)requestIdResponse["entity"]["data"]["updatedOn"];
                var httpWebRequest4 = ApiHandler.BuildRequest(this.MSMBaseUrl + string.Format("/api/serviceDesk/operational/requests/{0}/states", requestId), JsonHelper.ToJson(jsonBody), "POST");
                var moveStatusResponse = ApiHandler.ProcessRequest(httpWebRequest4, "Bearer " + this.MsmApiKey);
                if (moveStatusResponse.Contains("500"))
                {
                    this.AddMsmNote(requestId, "JIRA status update failed: a server error occured.");
                }
            }
            else
            {
                this.AddMsmNote(requestId, "JIRA status update failed: " + httpRequest.QueryString["status"] + " is not a valid next state.");
            }
            this.AddMsmNote(requestId, "JIRA status update failed: all linked JIRA issues must be in the same status.");
        }

        Log.Information("Response is " + response);
    }

    public Dictionary<int, string> GetMarvalProjectsRequestIDs(HttpRequest httpRequest)
    {

        Dictionary<int, string> result = new Dictionary<int, string>();
        var json = new StreamReader(httpRequest.InputStream).ReadToEnd();
        dynamic data = JObject.Parse(json);
        Log.Information("Data from Marval Projects is " + json);
        var MarvalProjectsRequestId = data.id;
        var queryString = "{  projects(input: {where: {id: {EQ: " + MarvalProjectsRequestId + " }}}) {    marvalid title   projectworkstages(input:{active:{EQ:true}}) {      id      name    }  }}";
        dynamic jobjectS = JObject.FromObject(new
        {
            query = queryString

        });
        var httpWebRequest = ApiHandler.BuildRequest(this.GraphApiBaseUrl, jobjectS.ToString(), "POST");
        var response = JObject.Parse(ApiHandler.ProcessRequest(httpWebRequest, this.openprojectapikey));
        Log.Information("Have response from GetMarvalProjectsRequestIDs as " + response);

        int MarvaID = (int)response["data"]["projects"][0]["marvalid"];
        string StageName = (string)response["data"]["projects"][0]["projectworkstages"][0]["name"];
        this.MarvalProjectName = (string)response["data"]["projects"][0]["title"];

        Log.Information("Have marval project name as " + this.MarvalProjectName);
        Log.Information("Have project work stage name as " + StageName);

        result.Add(MarvaID, StageName);
        return result;
    }


    public class WorkflowInfo
    {
        public int WorkflowId { get; set; }
        public int StatusId { get; set; }
    }

    private WorkflowInfo GetRequestWorkflowId(int requestId)
    {
        var httpWebRequest2 = ApiHandler.BuildRequest(this.MSMBaseUrl + string.Format("/api/serviceDesk/operational/requests/{0}", requestId), null, "GET");
        var requestIdResponse = JObject.Parse(ApiHandler.ProcessRequest(httpWebRequest2, "Bearer " + this.MsmApiKey));
        var workflowIdToken = requestIdResponse["entity"]["data"]["requestStatus"]["workflowStatus"]["workflow"]["id"];
        var statusIdToken = requestIdResponse["entity"]["data"]["requestStatus"]["workflowStatus"]["id"];

        int workflowId = workflowIdToken.Value<int>();
        int statusId = statusIdToken.Value<int>();

        return new WorkflowInfo { WorkflowId = workflowId, StatusId = statusId };
    }
    private void MoveMSMStatusComplete(HttpRequest httpRequest, string statusStrings)
    {

        string targetStateName;
        // The targetStateName actually contains the string that we need to deserialise, example
        // {"items":[["Accepted","Accepted"],["Backlog","Closed"]]}"
        Log.Information("Have targetStateName as " + statusStrings);
        var deserializedObject = JsonConvert.DeserializeObject<Dictionary<string, List<List<string>>>>(statusStrings);
        var items = deserializedObject["items"];

        // Get all project ids from Marval Projects
        //List<int> MarvalIds = GetMarvalProjectsRequestIDs(httpRequest);
        //    List<int> MarvalIds = GetMarvalProjectsRequestIDs(httpRequest);
        List<int> MarvalIds = new List<int>();
        Dictionary<int, string> marvalIdsAndStages = GetMarvalProjectsRequestIDs(httpRequest);

        foreach (var project in marvalIdsAndStages)
        {
            int requestId = project.Key;
            string stageName = project.Value;

            //Log.Information("MarvaID: " + marvaID);
            Log.Information("Stage Name: " + stageName);

            foreach (var item in items)
            {
                if (item[0] == stageName)
                {
                    targetStateName = item[1];
                    Log.Information("Will change requestID " + requestId + " to status " + targetStateName + " from status " + item[0]);

                    int[] marvalArray = MarvalIds.ToArray();
                    // foreach (int requestId in marvalArray)
                    // {
                    var workflowInfo = GetRequestWorkflowId(requestId);
                    var httpWebRequest = ApiHandler.BuildRequest(this.MSMBaseUrl + string.Format("/api/serviceDesk/operational/workflows/{0}", workflowInfo.WorkflowId), null, "GET");

                    JObject requestWorkflowResponse = JObject.Parse(ApiHandler.ProcessRequest(httpWebRequest, "Bearer " + this.MsmApiKey));
                    Log.Information("Workflows from Marval raw is " + requestWorkflowResponse);
                    WorkflowReadResponse response = requestWorkflowResponse["entity"].ToObject<WorkflowReadResponse>();
                    string statesAsString = JsonConvert.SerializeObject(response.data.states, Formatting.Indented);

                    //.Where(obj => obj.NextWorkflowStatusIds != null)

                    var distinctObjects = response.data.states
               .GroupBy(obj => obj.Id)
               .Select(group => group.First())
               .ToList();

                    foreach (var obj in distinctObjects)
                    {
                        // Check if NextWorkflowStatusIds is null and set it to an empty list if it is
                        if (obj.NextWorkflowStatusIds == null)
                        {
                            obj.NextWorkflowStatusIds = new List<int>();
                        }

                        obj.NextWorkflowStatusIds = obj.NextWorkflowStatusIds
                            .Where(id => distinctObjects.Any(o => o.Id == id))
                            .ToList();
                    }


                    Log.Information("Target states distinct is " + JsonConvert.SerializeObject(distinctObjects, Formatting.Indented));
                    var result = GetPathToState2(distinctObjects, workflowInfo.StatusId, targetStateName, 0);
                    List<int> path = result.Item1;
                    int targetStateID = result.Item2;
                    // List<int> path = [];
                    int endStateid = 0;
                    if (path.Count > 0)
                    {
                        Log.Information("Path to " + targetStateName);
                        foreach (int id in path)
                        {
                            Log.Information("Have id to go to " + id);
                            Dictionary<string, object> workflowUpdate = new Dictionary<string, object>();
                            workflowUpdate["WorkflowStatusId"] = id;

                            //jsonBody["UpdatedOn"] = (DateTime)requestIdResponse["entity"]["data"]["updatedOn"];
                            // Log.Information("Have json info used to change status as " + JsonHelper.ToJson(workflowUpdate));
                            //Log.Information("updating with json ", JsonHelper.ToJson(workflowUpdate));
                            var httpWebRequest4 = ApiHandler.BuildRequest(this.MSMBaseUrl + string.Format("/api/serviceDesk/integration/requests/{0}/partial", requestId), JsonHelper.ToJson(workflowUpdate), "PUT");
                            // Log.Information("Have response as " + httpWebRequest4);
                            var moveStatusResponse = ApiHandler.ProcessRequest(httpWebRequest4, "Bearer " + this.MsmApiKey);
                            //   Log.Information("Have response2 as " + moveStatusResponse);
                            // Log.Information("Path to state is " + id);
                            endStateid = id;
                        }
                        //    Log.Information("Target state is " + targetStateID);
                        //   Log.Information("End state is " + endStateid);
                        var workflowInfoEndState = GetRequestWorkflowId(requestId);

                        if (targetStateID == workflowInfoEndState.StatusId)
                        {
                            Log.Information("Target state is " + targetStateID);
                            AddMsmNote(requestId, "The status has been moved to \"" + targetStateName + "\" by the Related Marval Project - " + this.MarvalProjectName);
                        }
                        else
                        {
                            AddMsmNote(requestId, "Marval projects attempted to complete the status update of this request to " + targetStateName + " but was unable to due to a business rule violation");
                        }
                    }
                    else
                    {
                        Log.Information("Target state not found in the workflow  " + targetStateName);
                    }
                }
            }
            // }

        }

    }

    static Tuple<List<int>, int> GetPathToState2(List<State> states, int startStateID, string targetStateName, int targetstaticstate, List<List<int>> currBranches = null, int recurrNum = 0)
    {
        State targetState = states.Find(state => state.Name == targetStateName);
        Log.Information("Using New GetPathToState2");

        int endStateID = targetState.Id;

        if (targetstaticstate == 0)
        {
            Log.Information("Setting target state to " + endStateID + " in GetPathToState2");
            targetstaticstate = endStateID;
        }

        if (endStateID == startStateID)
        {
            //Log.Information("State already at end state");
            return Tuple.Create(new List<int>(), targetstaticstate);
        }
        if (!states.Exists(state2 => state2.Id == startStateID) || !states.Exists(endState => endState.Id == endStateID))
        {
            return Tuple.Create(new List<int>(), -1);
            //Log.Information("startStateID or end state could not be found");        // EXCEPTION
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

        List<List<int>> newBranches = new List<List<int>>();
        // string jsonstates = JsonConvert.SerializeObject(currBranches, Formatting.Indented);

        List<int> prevLastIds = new List<int>();

        foreach (List<int> branch in currBranches)
        {
            int lastID = branch[branch.Count - 1]; // The last ID in this branch.
            if (prevLastIds.Contains(lastID)) // Prevent duplicates by skipping over this branch if a previous branch already exists for this ID.
            {
                continue;
            }
            // Add a new branch to newBranches with the next ID or return if one of the new branches has the end state.
            foreach (int nextID in states.Find(state => state.Id == lastID).NextWorkflowStatusIds)
            {
                List<int> newBranch = new List<int>(branch);
                newBranch.Add(nextID);

                if (nextID == endStateID)
                {
                    return Tuple.Create(newBranch, targetstaticstate);
                }
                else
                {
                    newBranches.Add(newBranch);
                }
            }
            prevLastIds.Add(lastID);
        }

        recurrNum++;
        if (recurrNum > states.Count)
        {
            Log.Information("Recursion limit (number of states) reached, returning empty path");
            return Tuple.Create(new List<int>(), 0);
        }
        return GetPathToState2(states, startStateID, targetStateName, targetstaticstate, newBranches, recurrNum);
    }

    static Tuple<List<int>, int> GetPathToState2Old(List<State> states, int startStateID, string targetStateName, int targetstaticstate, List<List<int>> currBranches = null, int recurrNum = 0)
    {
        State targetState = states.Find(state => state.Name == targetStateName);

        int endStateID = targetState.Id;

        if (targetstaticstate == 0)
        {
            Log.Information("Setting target state to " + endStateID + " in GetPathToState2");
            targetstaticstate = endStateID;
        }

        if (endStateID == startStateID)
        {
            Log.Information("State already at end state");
            return Tuple.Create(new List<int>(), targetstaticstate);
        }
        if (states.Find(state => state.Id == startStateID) == null || states.Find(endState => endState.Id == endStateID) == null)
        {
            return Tuple.Create(new List<int>(), -1);
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

        List<List<int>> newBranches = new List<List<int>>();
        string json = JsonConvert.SerializeObject(newBranches, Formatting.Indented);
        string json2 = JsonConvert.SerializeObject(currBranches, Formatting.Indented);
        // string jsonstates = JsonConvert.SerializeObject(currBranches, Formatting.Indented);

        int maxIterations = 10; // Set the maximum number of iterations.
        int iterationCount = 0;

        foreach (List<int> branch in currBranches)
        {
            iterationCount++;
            if (iterationCount > maxIterations)
            {
                Log.Information("Max iteration count reached. Exiting loop.");
                break;
            }

            int lastID = branch[branch.Count - 1]; // The last ID in this branch.
            Log.Information("Last id is " + lastID);
            // Add a new branch to newBranches with the next ID or return if one of the new branches has the end state.
            foreach (int nextID in states.Find(state => state.Id == lastID).NextWorkflowStatusIds)
            {
                List<int> newBranch = new List<int>(branch);
                newBranch.Add(nextID);

                if (nextID == endStateID)
                {
                    return Tuple.Create(newBranch, targetstaticstate);
                }
                else
                {
                    newBranches.Add(newBranch);
                    string json2BR2 = JsonConvert.SerializeObject(newBranch, Formatting.Indented);
                    string json2BR = JsonConvert.SerializeObject(newBranches, Formatting.Indented);
                }
            }
            Log.Information("Iteration Count is " + iterationCount);
        }

        recurrNum++;
        if (recurrNum > 10)
        {
            return Tuple.Create(new List<int>(), -1);
            Log.Information("Somethihng recursed...");
            // EXCEPTION
            // Handle endState being inaccessible/paths looping
        }
        return GetPathToState2(states, startStateID, targetStateName, targetstaticstate, newBranches, recurrNum);

    }


    static List<int> GetPathToState(List<State> states, int startId, string targetStateName)
    {

        List<int> path = new List<int>();
        string currentStateStatusName = targetStateName;
        State currentState = states.Find(state => state.Id == startId);
        Log.Information("Using our current start state as " + currentState.Name);

        // This is where we are going
        State targetState = states.Find(state => state.Name == targetStateName);
        int stateID = targetState.Id;
        // Find if it's the next state, we can then just finish there.

        foreach (State state in states)
        {
            if (state.NextWorkflowStatusIds != null)
            {
                foreach (int statusId in state.NextWorkflowStatusIds)
                {
                    // If the current status id in nextworkflow status is equal to the state we want to go to 
                    // and if the id of the status we are iterating through matches the start state.
                    if (statusId == stateID) // && state.id == startId)
                    {

                        State currentStateIn = states.Find(state2 => state2.Id == stateID);
                        if (state.Id == startId)
                        {
                            // Log.Information("Have a new state to go from directly, state Name is {Name}, ID is {Id}", state.Name,currentStateIn.Id);

                            currentStateStatusName = currentStateIn.Name;
                            path.Add(currentStateIn.Id);
                            // return path;
                        }
                        // You can perform any desired actions here
                    }

                }


            }

        }
        List<int> newpaths = new List<int>();
        foreach (int statusId in currentState.NextWorkflowStatusIds)
        {
            newpaths.Add(statusId);
        }
        foreach (int newreworkflowpath in newpaths)
        {
            State currentWF = states.Find(state => state.Id == newreworkflowpath);
        }
        return path;
    }

    /// <summary>
    /// Move MSM Status
    /// </summary>
    /// <param name="httpRequest">The HttpRequest</param>
    /// <returns>Process Response</returns>
    private void MoveMsmStatus(HttpRequest httpRequest)
    {
        // int requestNumbers;
        int[] numbers = Array.Empty<int>();

        var json = new StreamReader(httpRequest.InputStream).ReadToEnd();
        dynamic data = JObject.Parse(json);
        Log.Information("Have json from openproject as " + json);
        var MarvalRequestNum = data.issue.fields[this.CustomFieldId].Value;
        numbers = ConvertStringToArray(MarvalRequestNum);
        foreach (int requestNumbers in numbers)
        {


            var httpWebRequest = ApiHandler.BuildRequest(this.MSMBaseUrl + string.Format("/api/serviceDesk/operational/requests?number={0}", requestNumbers), null, "GET");

            var requestNumberResponse = JObject.Parse(ApiHandler.ProcessRequest(httpWebRequest, ApiHandler.GetEncodedCredentials(this.MsmApiKey)));
            var requestId = (int)requestNumberResponse["collection"]["items"].First["entity"]["data"]["id"];

            httpWebRequest = ApiHandler.BuildRequest(this.MSMBaseUrl + string.Format("/api/serviceDesk/operational/requests/{0}", requestId), null, "GET");
            var requestIdResponse = JObject.Parse(ApiHandler.ProcessRequest(httpWebRequest, ApiHandler.GetEncodedCredentials(this.MsmApiKey)));
            var workflowId = requestIdResponse["entity"]["data"]["requestStatus"]["workflowStatus"]["workflow"]["id"];

            var formDetail = GetForm("moveStatus", requestIdResponse);
            Dictionary<string, object> jsonBody = GetFormFields(formDetail);
            // Get the next workflow states for the request...
            httpWebRequest = ApiHandler.BuildRequest(this.MSMBaseUrl + string.Format("/api/serviceDesk/operational/workflows/{0}/nextStates?requestId={1}&namePredicate=equals({2})", workflowId, requestId, httpRequest.QueryString["status"]), null, "GET");
            var requestWorkflowResponse = JObject.Parse(ApiHandler.ProcessRequest(httpWebRequest, ApiHandler.GetEncodedCredentials(this.MsmApiKey)));
            var workflowResponseItems = (IList<JToken>)requestWorkflowResponse["collection"]["items"];
            if (workflowResponseItems.Count > 0)
            {
                dynamic msmPutRequest = new ExpandoObject();
                msmPutRequest.WorkflowStatusId = workflowResponseItems[0]["entity"]["data"]["id"];
                msmPutRequest.UpdatedOn = (DateTime)requestNumberResponse["collection"]["items"].First["entity"]["data"]["updatedOn"];
                var WorkflowStatusId = workflowResponseItems[0]["entity"]["data"]["id"].ToString();
                var UpdatedOn = requestNumberResponse["collection"]["items"].First["entity"]["data"]["updatedOn"].ToString();
                jsonBody["WorkflowStatusId"] = WorkflowStatusId;
                jsonBody["UpdatedOn"] = (DateTime)requestNumberResponse["collection"]["items"].First["entity"]["data"]["updatedOn"];
                httpWebRequest = ApiHandler.BuildRequest(this.MSMBaseUrl + string.Format("/api/serviceDesk/operational/requests/{0}/states", requestId), JsonHelper.ToJson(jsonBody), "POST");
                var moveStatusResponse = ApiHandler.ProcessRequest(httpWebRequest, ApiHandler.GetEncodedCredentials(this.MsmApiKey));
                if (moveStatusResponse.Contains("500"))
                {
                    this.AddMsmNote(requestId, "Status update failed: a server error occured.");
                }
            }
            else
            {
                this.AddMsmNote(requestId, "Update failed: " + httpRequest.QueryString["status"] + " is not a valid next state.");
            }
            this.AddMsmNote(requestId, "Status update failed: all linked JIRA issues must be in the same status.");
        }
    }


    /// <summary>
    /// Add MSM Note
    /// </summary>   
    private void AddMsmNote(int requestNumber, string note)
    {
        Log.Information("Adding note with ID " + requestNumber);
        IDictionary<string, object> body = new Dictionary<string, object>();
        body.Add("id", requestNumber);
        body.Add("content", note);
        body.Add("type", "public");
        string jsonNote = JsonHelper.ToJson(body);
        Log.Information("Have json note as " + jsonNote);
        var httpWebRequest = ApiHandler.BuildRequest(this.MSMBaseUrl + string.Format("/api/serviceDesk/operational/requests/{0}/notes/", requestNumber), JsonHelper.ToJson(body), "POST");
        ApiHandler.ProcessRequest(httpWebRequest, "Bearer " + this.MsmApiKey);
    }

    /// <summary>
    /// Check and return missing plugin settings
    /// </summary>
    /// <returns>Json Object containing any settings that failed the check</returns>
    private JObject PreRequisiteCheck()
    {
        var preReqs = new JObject();
        if (string.IsNullOrWhiteSpace(this.CustomFieldName))
        {
            Log.Information("Have a validation error on custom field name");
            preReqs.Add("jiraCustomFieldName", false);
        }
        if (string.IsNullOrWhiteSpace(this.ApiBaseUrl))
        {
            Log.Information("Have a validation error on ApiBaseUrl");
            preReqs.Add("jiraBaseUrl", false);
        }
        if (string.IsNullOrWhiteSpace(this.Username))
        {
            Log.Information("Have a validation error on Username");
            preReqs.Add("jiraUsername", false);
        }
        if (string.IsNullOrWhiteSpace(this.Password))
        {
            Log.Information("Have a validation error on Password");
            preReqs.Add("jiraPassword", false);
        }

        return preReqs;
    }

    //Generic Methods

    /// <summary>
    /// Builds a HttpWebRequest
    /// </summary>
    /// <param name="uri">The uri for request</param>
    /// <param name="body">The body for the request</param>
    /// <param name="method">The verb for the request</param>
    /// <returns>The HttpWebRequest ready to be processed</returns>
    private static HttpWebRequest BuildRequest(string uri = null, string body = null, string method = "GET")
    {
        var request = WebRequest.Create(new UriBuilder(uri).Uri) as HttpWebRequest;
        // Log.Information("Request URI is " + uri);
        // Log.Information("Request body is " + body);
        //  Log.Information("Building request " + request);
        request.Method = method.ToUpperInvariant();
        request.ContentType = "application/json";
        if (body == null) return request;
        using (var writer = new StreamWriter(request.GetRequestStream()))
        {
            // Log.Information("body is " + body);
            writer.Write(body);
        }

        return request;
    }

    /// <summary>
    /// Proccess a HttpWebRequest
    /// </summary>
    /// <param name="request">The HttpWebRequest</param>
    /// <param name="credentials">The Credentails to use for the API</param>
    /// <returns>Process Response</returns>
    private static string ProcessRequest(HttpWebRequest request, string credentials)
    {
        //  Log.Information("Processing request with credentials " + credentials);
        var result = "";
        try
        {
            request.Headers.Add("Authorization", credentials);
            HttpWebResponse response = request.GetResponse() as HttpWebResponse;
            using (StreamReader reader = new StreamReader(response.GetResponseStream()))
            {
                result = reader.ReadToEnd();
            }
        }
        catch (WebException webEx)
        {

            var errResp = webEx.Response;
            Log.Information("Have error response, response is " + errResp);
            using (var stream = errResp.GetResponseStream())
            {
                using (var reader = new StreamReader(stream))
                {
                    result = reader.ReadToEnd();
                    Log.Information("Result from stream error " + result);
                    Log.Information("url is" + request.Address);

                }
            }

        }
        return result;
    }

    /// <summary>
    /// Encodes Credentials
    /// </summary>
    /// <param name="credentials">The string to encode</param>
    /// <returns>base64 encoded string</returns>
    private static string GetEncodedCredentials(string credentials)
    {
        var byteCredentials = Encoding.UTF8.GetBytes(credentials);
        return Convert.ToBase64String(byteCredentials);
    }

    /// <summary>
    /// JsonHelper Functions
    /// </summary>
    internal class JsonHelper
    {
        public static string ToJson(object obj)
        {
            return JsonConvert.SerializeObject(obj);
        }

        public static dynamic FromJson(string json)
        {
            return JObject.Parse(json);
        }
    }

    private string GetRelativeTime(DateTime date)
    {
        var ts = new TimeSpan(DateTime.Now.Ticks - date.Ticks);
        var delta = Math.Abs(ts.TotalSeconds);
        var localTimeOfDay = date.ToShortTimeString();

        if (delta < 1 * ApiHandler.minute)
        {
            return ts.Seconds == 1 ? this.GetResourceString("@@OneSecondAgo") : this.GetResourceString("@@AFewSecondsAgo");
        }

        if (delta < 2 * ApiHandler.minute)
        {
            return this.GetResourceString("@@OneMinuteAgo");
        }

        if (delta < 60 * ApiHandler.minute)
        {
            return this.GetResourceString("@@MinutesAgo", Math.Floor(ts.TotalMinutes));
        }

        if (delta < 61 * ApiHandler.minute)
        {
            return this.GetResourceString("@@OneHourAgo");
        }

        if (delta < 24 * ApiHandler.hour)
        {
            return this.GetResourceString("@@HoursAgo", Math.Floor(ts.TotalHours));
        }

        if (delta < 48 * ApiHandler.hour)
        {
            return this.GetResourceString("@@YesterdayAt", localTimeOfDay);
        }

        if (delta < 7 * ApiHandler.day)
        {
            return this.GetResourceString("@@DaysAgo", Math.Floor(ts.TotalDays));
        }

        return date.ToString("dd/MMM/yy hh:mm tt");
    }
}
