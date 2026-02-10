import { Module } from "@nestjs/common";
import { OsrmRoutingProvider } from "./osrm-routing.provider";
import { RoutingProviderResolver } from "./routing-provider-resolver.service";

@Module({
  providers: [OsrmRoutingProvider, RoutingProviderResolver],
  exports: [RoutingProviderResolver],
})
export class MapsModule {}
