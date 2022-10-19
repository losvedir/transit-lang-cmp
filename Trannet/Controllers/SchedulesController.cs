using Microsoft.AspNetCore.Mvc;
using Trannet.Services;

namespace Trannet.Controllers;

[ApiController]
[Route("[controller]")]
public class SchedulesController : ControllerBase
{
  private readonly ILogger<SchedulesController> _logger;

  public SchedulesController(ILogger<SchedulesController> logger)
  {
    _logger = logger;
  }

  [HttpGet("{routeId}")]
  public List<TripResponse> Get(string routeId)
  {
    return GTFSService.SchedulesForRoute(routeId);
  }
}
