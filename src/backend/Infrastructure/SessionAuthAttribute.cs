using System;
using System.Web.Mvc;

namespace Shop.Infrastructure
{
    public class SessionAuthAttribute : ActionFilterAttribute
    {
        public override void OnActionExecuting(ActionExecutingContext filterContext)
        {
            var session = filterContext.HttpContext.Session;
            var userId = session["UserId"];

            if (userId == null)
            {
                var request = filterContext.HttpContext.Request;
                var returnUrl = request.Url != null ? request.Url.PathAndQuery : "/";
                var url = new UrlHelper(filterContext.RequestContext);
                filterContext.Result = new RedirectResult(url.Action("Login", "Account", new { ReturnUrl = returnUrl }));
                return;
            }

            base.OnActionExecuting(filterContext);
        }
    }
}
