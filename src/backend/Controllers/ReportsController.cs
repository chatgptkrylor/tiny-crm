using System.Web.Mvc;
using Shop.Infrastructure;
using Shop.Models;
using Shop.Repository;

namespace Shop.Controllers
{
    [SessionAuth]
    public class ReportsController : Controller
    {
        private readonly ICustomerRepository _repo;

        public ReportsController()
        {
            _repo = new CustomerRepository();
        }

        public ActionResult Index()
        {
            var statusCounts = _repo.GetCountByStatus();
            var total = _repo.GetTotalCount();
            var model = new ReportViewModel
            {
                StatusCounts = statusCounts,
                TotalCustomers = total
            };
            return View(model);
        }
    }
}