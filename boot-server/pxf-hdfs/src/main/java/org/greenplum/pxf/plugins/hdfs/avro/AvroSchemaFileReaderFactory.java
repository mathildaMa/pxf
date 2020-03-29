package org.greenplum.pxf.plugins.hdfs.avro;

public class AvroSchemaFileReaderFactory {
    private static final AvroSchemaFileReaderFactory instance = new AvroSchemaFileReaderFactory();

    public static AvroSchemaFileReaderFactory getInstance() {
        return instance;
    }

    public AvroSchemaFileReader getAvroSchemaFileReader(String userProvidedSchemaFile) {
        if (userProvidedSchemaFile.matches("^.*\\.avsc$")) {
            return new JsonAvroSchemaFileReader();
        }
        return new BinaryAvroSchemaFileReader();
    }
}
