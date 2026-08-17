using System.Web.Mvc;

namespace Shop.Controllers
{
    public class HomeController : Controller
    {
        public ActionResult Index()
        {
            return Content("Tiny CRM — scaffolding ready");
        }
    }
}