package org.greenplum.pxf.service.bridge;

import org.greenplum.pxf.api.ReadVectorizedResolver;
import org.greenplum.pxf.api.model.RequestContext;
import org.greenplum.pxf.api.model.StreamingResolver;
import org.greenplum.pxf.api.utilities.Utilities;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class SimpleBridgeFactory implements BridgeFactory {

    private static final Logger LOG = LoggerFactory.getLogger(SimpleBridgeFactory.class);
    private static final SimpleBridgeFactory instance = new SimpleBridgeFactory();

    /**
     * Returns a singleton instance of the factory.
     *
     * @return a singleton instance of the factory.
     */
    public static BridgeFactory getInstance() {
        return instance;
    }

    @Override
    public Bridge getReadBridge(RequestContext context) {

        if (context.getStatsSampleRatio() > 0) {
            return new ReadSamplingBridge(context);
        } else if (Utilities.aggregateOptimizationsSupported(context)) {
            return new AggBridge(context);
        } else if (useVectorization(context)) {
            return new ReadVectorizedBridge(context);
        } else {
            Class<?> resolverClass = null;
            try {
                resolverClass = Class.forName(context.getResolver());
            } catch (ClassNotFoundException e) {
                LOG.info("Could not get class for {}: {}", context.getResolver(), e);
            }
            if (resolverClass != null && StreamingResolver.class.isAssignableFrom(resolverClass)) {
                return new StreamingImageReadBridge(context);
            }
        }
        return new ReadBridge(context);
    }

    @Override
    public Bridge getWriteBridge(RequestContext context) {
        return new WriteBridge(context);
    }

    /**
     * Determines whether use vectorization
     *
     * @param requestContext input protocol data
     * @return true if vectorization is applicable in a current context
     */
    private boolean useVectorization(RequestContext requestContext) {
        return Utilities.implementsInterface(requestContext.getResolver(), ReadVectorizedResolver.class);
    }

}
