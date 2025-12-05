// MongoDB seed script for Graylog streams
// This runs directly against MongoDB, bypassing Graylog API

// Get default index set ID
const defaultIndexSet = db.index_sets.findOne({ default: true });
if (!defaultIndexSet) {
  print("ERROR: No default index set found");
  quit(1);
}

const indexSetId = defaultIndexSet._id;
print("Using default index set: " + indexSetId);

// Stream 1: All Quantus Nodes
const stream1Id = ObjectId();
const stream1 = {
  _id: stream1Id,
  title: "All Quantus Nodes",
  description: "All validator node logs from Quantus Network",
  disabled: false,
  matching_type: "AND",
  remove_matches_from_default_stream: false,
  index_set_id: indexSetId,
  created_at: new Date(),
  creator_user_id: "admin",
  is_default: false
};

// Check if stream already exists
const existing1 = db.streams.findOne({ title: "All Quantus Nodes" });
if (existing1) {
  print("Stream 'All Quantus Nodes' already exists");
} else {
  db.streams.insertOne(stream1);
  
  // Add stream rule
  db.stream_rules.insertOne({
    _id: ObjectId(),
    stream_id: stream1Id,
    type: 2, // EXACT match
    field: "tag",
    value: "quantus",
    inverted: false,
    description: "Match Quantus tag"
  });
  
  print("✓ Created stream: All Quantus Nodes");
}

// Stream 2: Quantus Errors
const stream2Id = ObjectId();
const stream2 = {
  _id: stream2Id,
  title: "Quantus Errors",
  description: "Error-level logs from Quantus nodes",
  disabled: false,
  matching_type: "AND",
  remove_matches_from_default_stream: false,
  index_set_id: indexSetId,
  created_at: new Date(),
  creator_user_id: "admin",
  is_default: false
};

const existing2 = db.streams.findOne({ title: "Quantus Errors" });
if (existing2) {
  print("Stream 'Quantus Errors' already exists");
} else {
  db.streams.insertOne(stream2);
  
  // Add stream rules
  db.stream_rules.insertOne({
    _id: ObjectId(),
    stream_id: stream2Id,
    type: 2, // EXACT match
    field: "tag",
    value: "quantus",
    inverted: false,
    description: "Match Quantus tag"
  });
  
  db.stream_rules.insertOne({
    _id: ObjectId(),
    stream_id: stream2Id,
    type: 1, // GREATER than
    field: "level",
    value: "3",
    inverted: false,
    description: "Match ERROR level (>=3)"
  });
  
  print("✓ Created stream: Quantus Errors");
}

print("✓ MongoDB seed completed");


