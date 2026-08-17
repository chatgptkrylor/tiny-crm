using System.Web.Mvc;
using Shop.Infrastructure;
using Shop.Models;
using Shop.Repository;

namespace Shop.Controllers
{
    [SessionAuth]
    public class DashboardController : Controller
    {
        private readonly ICustomerRepository _customerRepo;
        private readonly IInteractionRepository _interactionRepo;

        public DashboardController()
        {
            _customerRepo = new CustomerRepository();
            _interactionRepo = new InteractionRepository();
        }

        public ActionResult Index()
        {
            var statusCounts = _customerRepo.GetCountByStatus();
            var recentInteractions = _interactionRepo.GetRecent(5);
            var totalCount = _customerRepo.GetTotalCount();

            var model = new DashboardViewModel
            {
                TotalCustomers = totalCount,
                StatusCounts = statusCounts,
                RecentInteractions = recentInteractions,
                Username = Session["Username"] as string
            };

            return View(model);
        }
    }
}