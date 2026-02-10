import { Injectable, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { OsrmRoutingProvider } from "./osrm-routing.provider";
import { RoutingProvider } from "./routing-provider";

@Injectable()
export class RoutingProviderResolver {
  private readonly logger = new Logger(RoutingProviderResolver.name);

  constructor(
    private readonly configService: ConfigService,
    private readonly osrmProvider: OsrmRoutingProvider,
  ) {}

  getProvider(): RoutingProvider {
    const configured = (
      this.configService.get<string>("ROUTE_PROVIDER") || "osrm"
    ).toLowerCase();
    if (configured === "osrm") {
      return this.osrmProvider;
    }

    this.logger.warn(
      `Unsupported ROUTE_PROVIDER="${configured}", falling back to "osrm".`,
    );
    return this.osrmProvider;
  }
}
