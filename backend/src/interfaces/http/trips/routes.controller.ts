import { Body, Controller, Post } from "@nestjs/common";
import { ApiOperation, ApiResponse, ApiTags } from "@nestjs/swagger";
import {
  RouteEstimateDto,
  RouteEstimateResponseDto,
} from "@application/dto/trips/trips.dto";
import { TripsService } from "@application/services/trips/trips.service";

@ApiTags("Routes")
@Controller("routes")
export class RoutesController {
  constructor(private readonly tripsService: TripsService) {}

  @Post("estimate")
  @ApiOperation({
    summary: "Estimate route distance, duration and suggested cost",
  })
  @ApiResponse({
    status: 201,
    description: "Route estimation",
    type: RouteEstimateResponseDto,
  })
  async estimate(
    @Body() dto: RouteEstimateDto,
  ): Promise<RouteEstimateResponseDto> {
    return this.tripsService.estimateRouteCost(dto);
  }
}
