package org.greenplum.pxf.plugins.hdfs.avro;

import org.junit.Before;
import org.junit.Test;

import static org.junit.Assert.assertTrue;

public class AvroSchemaFileReaderFactoryTest {

    private AvroSchemaFileReaderFactory avroSchemaFileReaderFactory;

    @Before
    public void setup() {
        avroSchemaFileReaderFactory = new AvroSchemaFileReaderFactory();
    }

    @Test
    public void testGetJsonReader() {
        assertTrue(avroSchemaFileReaderFactory.getAvroSchemaFileReader("foobar.avsc") instanceof JsonAvroSchemaFileReader);
    }

    @Test
    public void testGetBinaryReader() {
        assertTrue(avroSchemaFileReaderFactory.getAvroSchemaFileReader("foobar.avro") instanceof BinaryAvroSchemaFileReader);
    }
}