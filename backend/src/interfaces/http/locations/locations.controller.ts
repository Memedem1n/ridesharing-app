import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiQuery, ApiResponse, ApiTags } from '@nestjs/swagger';
import {
  LocationSuggestionDto,
  LocationsService,
} from '@application/services/locations/locations.service';

@ApiTags('Locations')
@Controller('locations')
export class LocationsController {
  constructor(private readonly locationsService: LocationsService) {}

  @Get('search')
  @ApiOperation({ summary: 'Location search (Nominatim proxy)' })
  @ApiQuery({ name: 'q', required: true, example: 'İstanbul' })
  @ApiResponse({ status: 200, description: 'Suggestion list' })
  async search(@Query('q') q: string): Promise<LocationSuggestionDto[]> {
    return this.locationsService.search(q);
  }
}

