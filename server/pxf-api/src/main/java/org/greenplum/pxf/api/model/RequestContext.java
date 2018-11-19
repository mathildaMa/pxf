package org.greenplum.pxf.api.model;

/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */


import org.apache.commons.lang.StringUtils;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.greenplum.pxf.api.utilities.ColumnDescriptor;
import org.greenplum.pxf.api.utilities.EnumAggregationType;

import java.util.ArrayList;
import java.util.Map;
import java.util.stream.Stream;

import static org.greenplum.pxf.api.model.HDFSPlugin.DEFAULT_SERVER_NAME;

/**
 * Common configuration available to all PXF plugins. Represents input data
 * coming from client applications, such as GPDB.
 */
public class RequestContext {

    public static final String DELIMITER_KEY = "DELIMITER";
    //public static final String USER_PROP_PREFIX = "X-GP-OPTIONS-";
    public static final int INVALID_SPLIT_IDX = -1;

    private static final Log LOG = LogFactory.getLog(RequestContext.class);

    // ----- NAMED PROPERTIES -----
    private String accessor;
    private EnumAggregationType aggType;
    private int dataFragment; /* should be deprecated */
    private String dataSource;
    private String fragmenter;
    private int fragmentIndex;
    private byte[] fragmentMetadata = null;
    private String filterString;
    private boolean filterStringValid;
    private String metadata;

    /**
     * Number of attributes projected in query.
     * <p>
     * Example:
     * SELECT col1, col2, col3... : number of attributes projected - 3
     * SELECT col1, col2, col3... WHERE col4=a : number of attributes projected - 4
     * SELECT *... : number of attributes projected - 0
     */
    private int numAttrsProjected;

    private String profile;

    /**
     * The name of the recordkey column. It can appear in any location in the
     * columns list. By specifying the recordkey column, the user declares that
     * he is interested to receive for every record retrieved also the the
     * recordkey in the database. The recordkey is present in HBase table (it is
     * called rowkey), and in sequence files. When the HDFS storage element
     * queried will not have a recordkey and the user will still specify it in
     * the "create external table" statement, then the values for this field
     * will be null. This field will always be the first field in the tuple
     * returned.
     */
    protected ColumnDescriptor recordkeyColumn;

    private String remoteLogin;
    private String remoteSecret;
    private String resolver;
    private int segmentId;
    /**
     * The name of the server to access. The name will be used to build
     * a path for the config files (i.e. $PXF_CONF/servers/$serverName/*.xml)
     */
    private String serverName = DEFAULT_SERVER_NAME;
    private int totalSegments;
    /**
     * When false the bridge has to run in synchronized mode. default value -
     * true.
     */
    private boolean threadSafe;

    private ArrayList<ColumnDescriptor> tupleDescription;
    private String user;
    private byte[] userData;

    // ----- USER-DEFINED OPTIONS other than NAMED PROPERTIES -----
    protected Map<String, String> options;


    //TODO remove
    /**
     * Returns the stream of key-value pairs defined in the request parameters
     *
     * @returns stream of map entries
     */
    public Stream<Map.Entry<String, String>> getUserPropertiesStream() {
        return requestParametersMap.entrySet().stream()
                .filter(e -> e.getKey().toUpperCase().startsWith(USER_PROP_PREFIX) ||
                        e.getKey().toLowerCase().startsWith(USER_PROP_PREFIX.toLowerCase()));
    }

    /**
     * Returns a user defined property.
     *
     * @param userProp the lookup user property
     * @return property value as a String
     */
    /*
    public String getUserProperty(String userProp) {
        return requestParametersMap.get(USER_PROP_PREFIX + userProp.toUpperCase());
    }
    */

    public String getOption(String option) {
        return options.get(option);
    }

    public String getOption(String option, String defaultValue) {
        return options.getOrDefault(option, defaultValue);
    }


    public void setAccessor(String accessor) {
        this.accessor = accessor;
    }

    public void setDataFragment(int dataFragment) {
        this.dataFragment = dataFragment;
    }

    public void setFragmenter(String fragmenter) {
        this.fragmenter = fragmenter;
    }

    public void setFilterString(String filterString) {
        this.filterString = filterString;
    }

    public boolean isFilterStringValid() {
        return filterStringValid;
    }

    public void setFilterStringValid(boolean filterStringValid) {
        this.filterStringValid = filterStringValid;
    }

    public void setMetadata(String metadata) {
        this.metadata = metadata;
    }

    public void setProfile(String profile) {
        this.profile = profile;
    }

    public void setRecordkeyColumn(ColumnDescriptor recordkeyColumn) {
        this.recordkeyColumn = recordkeyColumn;
    }

    public String getRemoteLogin() {
        return remoteLogin;
    }

    public void setRemoteLogin(String remoteLogin) {
        this.remoteLogin = remoteLogin;
    }

    public String getRemoteSecret() {
        return remoteSecret;
    }

    public void setRemoteSecret(String remoteSecret) {
        this.remoteSecret = remoteSecret;
    }

    public void setResolver(String resolver) {
        this.resolver = resolver;
    }

    public void setSegmentId(int segmentId) {
        this.segmentId = segmentId;
    }

    public void setTotalSegments(int totalSegments) {
        this.totalSegments = totalSegments;
    }

    public void setThreadSafe(boolean threadSafe) {
        this.threadSafe = threadSafe;
    }

    public void setTupleDescription(ArrayList<ColumnDescriptor> tupleDescription) {
        this.tupleDescription = tupleDescription;
    }

    public void setUser(String user) {
        this.user = user;
    }

    public byte[] getUserData() {
        return userData;
    }

    public void setUserData(byte[] userData) {
        this.userData = userData;
    }

    public Map<String, String> getOptions() {
        return options;
    }

    public void setOptions(Map<String, String> options) {
        this.options = options;
    }

    /**
     * Sets the byte serialization of a fragment meta data.
     *
     * @param location start, len, and location of the fragment
     */
    public void setFragmentMetadata(byte[] location) {
        this.fragmentMetadata = location;
    }

    /**
     * The byte serialization of a data fragment.
     *
     * @return serialized fragment metadata
     */
    public byte[] getFragmentMetadata() {
        return fragmentMetadata;
    }

    /**
     * Gets any custom user data that may have been passed from the fragmenter.
     * Will mostly be used by the accessor or resolver.
     *
     * @return fragment user data
     */
    public byte[] getFragmentUserData() {
        return userData;
    }

    /**
     * Sets any custom user data that needs to be shared across plugins. Will
     * mostly be set by the fragmenter.
     *
     * @param userData user data
     */
    public void setFragmentUserData(byte[] userData) {
        this.userData = userData;
    }

    /**
     * Returns the number of segments in GPDB.
     *
     * @return number of segments
     */
    public int getTotalSegments() {
        return totalSegments;
    }

    /**
     * Returns the current segment ID in GPDB.
     *
     * @return current segment ID
     */
    public int getSegmentId() {
        return segmentId;
    }

    /**
     * Returns true if there is a filter string to parse.
     *
     * @return whether there is a filter string
     */
    public boolean hasFilter() {
        return filterStringValid;
    }

    /**
     * Returns the filter string, <tt>null</tt> if #hasFilter is <tt>false</tt>.
     *
     * @return the filter string or null
     */
    public String getFilterString() {
        return filterString;
    }

    /**
     * Returns tuple description.
     *
     * @return tuple description
     */
    public ArrayList<ColumnDescriptor> getTupleDescription() {
        return tupleDescription;
    }

    /**
     * Returns the number of columns in tuple description.
     *
     * @return number of columns
     */
    public int getColumns() {
        return tupleDescription.size();
    }

    /**
     * Returns column index from tuple description.
     *
     * @param index index of column
     * @return column by index
     */
    public ColumnDescriptor getColumn(int index) {
        return tupleDescription.get(index);
    }

    /**
     * Returns the column descriptor of the recordkey column. If the recordkey
     * column was not specified by the user in the create table statement will
     * return null.
     *
     * @return column of record key or null
     */
    public ColumnDescriptor getRecordkeyColumn() {
        return recordkeyColumn;
    }

    /**
     * Returns the data source of the required resource (i.e a file path or a
     * table name).
     *
     * @return data source
     */
    public String getDataSource() {
        return dataSource;
    }

    /**
     * Sets the data source for the required resource.
     *
     * @param dataSource data source to be set
     */
    public void setDataSource(String dataSource) {
        this.dataSource = dataSource;
    }

    /**
     * Returns the profile name.
     *
     * @return name of profile
     */
    public String getProfile() {
        return profile;
    }

    /**
     * Returns the ClassName for the java class that was defined as Accessor.
     *
     * @return class name for Accessor
     */
    public String getAccessor() {
        return accessor;
    }

    /**
     * Returns the ClassName for the java class that was defined as Resolver.
     *
     * @return class name for Resolver
     */
    public String getResolver() {
        return resolver;
    }

    /**
     * Returns the ClassName for the java class that was defined as BaseFragmenter
     * or null if no fragmenter was defined.
     *
     * @return class name for BaseFragmenter or null
     */
    public String getFragmenter() {
        return fragmenter;
    }

    /**
     * Returns the ClassName for the java class that was defined as Metadata
     * or null if no metadata was defined.
     *
     * @return class name for METADATA or null
     */
    public String getMetadata() {
        return metadata;
    }

    /**
     * Returns the contents of pxf_remote_service_login set in Gpdb. Should the
     * user set it to an empty string this function will return null.
     *
     * @return remote login details if set, null otherwise
     */
    public String getLogin() {
        return remoteLogin;
    }

    /**
     * Returns the contents of pxf_remote_service_secret set in Gpdb. Should the
     * user set it to an empty string this function will return null.
     *
     * @return remote password if set, null otherwise
     */
    public String getSecret() {
        return remoteSecret;
    }

    /**
     * Returns whether this request is thread safe.
     * If it is not, request will be handled consequentially and not in parallel.
     *
     * @return whether the request is thread safe
     */
    public boolean isThreadSafe() {
        return threadSafe;
    }

    /**
     * Returns a data fragment index. plan to deprecate it in favor of using
     * getFragmentMetadata().
     *
     * @return data fragment index
     */
    public int getDataFragment() {
        return dataFragment;
    }

    /**
     * Returns aggregate type, i.e - count, min, max, etc
     *
     * @return aggregate type
     */
    public EnumAggregationType getAggType() {
        return aggType;
    }

    /**
     * Sets aggregate type, one of @see EnumAggregationType value
     *
     * @param aggType aggregate type
     */
    public void setAggType(EnumAggregationType aggType) {
        this.aggType = aggType;
    }

    /**
     * Returns index of a fragment in a file
     *
     * @return index of a fragment
     */
    public int getFragmentIndex() {
        return fragmentIndex;
    }

    /**
     * Sets index of a fragment in a file
     *
     * @param fragmentIndex index of a fragment
     */
    public void setFragmentIndex(int fragmentIndex) {
        this.fragmentIndex = fragmentIndex;
    }

    /**
     * Returns number of attributes projected in a query
     *
     * @return number of attributes projected
     */
    public int getNumAttrsProjected() {
        return numAttrsProjected;
    }

    /**
     * Sets number of attributes projected
     *
     * @param numAttrsProjected number of attrivutes projected
     */
    public void setNumAttrsProjected(int numAttrsProjected) {
        this.numAttrsProjected = numAttrsProjected;
    }

    /**
     * Returns the name of the server in a multi-server setup
     *
     * @return the name of the server
     */
    public String getServerName() {
        return serverName;
    }

    /**
     * Sets the name of the server in a multi-server setup.
     * If the name is blank, it is defaulted to "default"
     *
     * @param serverName the name of the server
     */
    public void setServerName(String serverName) {
        if (StringUtils.isNotBlank(serverName)) {
            this.serverName = serverName;
        }
    }

    /**
     * Returns identity of the end-user making the request.
     *
     * @return userid
     */
    public String getUser() {
        return user;
    }

}