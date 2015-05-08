require 'spec_helper'
require 'zermelo/records/influxdb'

describe Zermelo::Records::InfluxDB, :influxdb => true do

  module Zermelo
    class InfluxDBExample
      include Zermelo::Records::InfluxDB

      define_attributes :name   => :string,
                        :email  => :string,
                        :active => :boolean

      validates :name, :presence => true

      has_many :children, :class_name => 'Zermelo::InfluxDBChild'
      # has_sorted_set :sorted, :class_name => 'Zermelo::InfluxDBSorted'
    end

    class InfluxDBChild
      include Zermelo::Records::InfluxDB

      define_attributes :name => :string,
                        :important => :boolean

      belongs_to :example, :class_name => 'Zermelo::InfluxDBExample', :inverse_of => :children

      validates :name, :presence => true
    end

    class InfluxDBSorted
      include Zermelo::Records::InfluxDB

      define_attributes :name => :string,
                        :important => :boolean

      belongs_to :example, :class_name => 'Zermelo::InfluxDBExample', :inverse_of => :sorted

      validates :name, :presence => true
    end
  end

  def create_example(attrs = {})
    Zermelo.influxdb.write_point("influx_db_example/#{attrs[:id]}", attrs)
  end

  let(:influxdb) { Zermelo.influxdb }

  it "finds a record by id in influxdb" do
    create_example(:id => '1', :name => 'Jane Doe', :email => 'jdoe@example.com',
      :active => 'true')

    example = Zermelo::InfluxDBExample.find_by_id('1')
    expect(example).not_to be_nil

    expect(example).to respond_to(:name)
    expect(example.name).to eql('Jane Doe')
    expect(example).to respond_to(:email)
    expect(example.email).to eql('jdoe@example.com')
    expect(example).to respond_to(:active)
    expect(example.active).to be true
  end

  it "can update a value in influxdb" do
    create_example(:id => '1', :name => 'Jane Doe', :email => 'jdoe@example.com',
      :active => 'true')

    example = Zermelo::InfluxDBExample.find_by_id('1')
    expect(example).not_to be_nil

    example.name = 'John Smith'
    example.save

    other_example = Zermelo::InfluxDBExample.find_by_id('1')
    expect(other_example).not_to be_nil
    expect(other_example.name).to eq('John Smith')
  end

  it "destroys a single record from influxdb" do
    create_example(:id => '1', :name => 'Jane Doe', :email => 'jdoe@example.com',
      :active => 'true')

    example = Zermelo::InfluxDBExample.find_by_id('1')
    example.destroy
    example_chk = Zermelo::InfluxDBExample.find_by_id('1')
    expect(example_chk).to be_nil
  end

  it "resets changed state on refresh" do
    create_example(:id => '1', :name => 'Jane Doe', :email => 'jdoe@example.com',
      :active => 'true')
    example = Zermelo::InfluxDBExample.find_by_id('1')

    example.name = "King Henry VIII"
    expect(example.changed).to include('name')
    expect(example.changes).to eq({'name' => ['Jane Doe', 'King Henry VIII']})

    example.refresh
    expect(example.changed).to be_empty
    expect(example.changes).to be_empty
  end

  context 'filters' do

    it "returns all record ids" do
      create_example(:id => '1', :name => 'Jane Doe', :email => 'jdoe@example.com',
        :active => 'true')
      create_example(:id => '2', :name => 'John Smith',
        :email => 'jsmith@example.com', :active => 'false')

      examples = Zermelo::InfluxDBExample.ids
      expect(examples).not_to be_nil
      expect(examples).to be_an(Array)
      expect(examples.size).to eq(2)
      expect(examples).to contain_exactly('2', '1')
    end

    it "returns a count of records" do
      create_example(:id => '1', :name => 'Jane Doe', :email => 'jdoe@example.com',
        :active => 'true')
      create_example(:id => '2', :name => 'John Smith',
        :email => 'jsmith@example.com', :active => 'false')

      example_count = Zermelo::InfluxDBExample.count
      expect(example_count).not_to be_nil
      expect(example_count).to be_an(Integer)
      expect(example_count).to eq(2)
    end

    it "returns all records" do
      create_example(:id => '1', :name => 'Jane Doe', :email => 'jdoe@example.com',
        :active => 'true')
      create_example(:id => '2', :name => 'John Smith',
        :email => 'jsmith@example.com', :active => 'false')

      examples = Zermelo::InfluxDBExample.all
      expect(examples).not_to be_nil
      expect(examples).to be_an(Array)
      expect(examples.size).to eq(2)
      expect(examples.map(&:id)).to contain_exactly('2', '1')
    end

    it "filters all class records by attribute values" do
      create_example(:id => '1', :name => 'Jane Doe', :email => 'jdoe@example.com',
        :active => 'true')
      create_example(:id => '2', :name => 'John Smith',
        :email => 'jsmith@example.com', :active => 'false')

      example = Zermelo::InfluxDBExample.intersect(:active => true).all
      expect(example).not_to be_nil
      expect(example).to be_an(Array)
      expect(example.size).to eq(1)
      expect(example.map(&:id)).to eq(['1'])
    end

    it "chains two intersect filters together" do
      create_example(:id => '1', :name => 'Jane Doe', :email => 'jdoe@example.com',
        :active => 'true')
      create_example(:id => '2', :name => 'John Smith',
        :email => 'jsmith@example.com', :active => 'false')
      create_example(:id => '3', :name => 'Fred Bloggs',
        :email => 'fbloggs@example.com', :active => 'true')

      example = Zermelo::InfluxDBExample.intersect(:active => true).
        intersect(:name => 'Jane Doe').all
      expect(example).not_to be_nil
      expect(example).to be_an(Array)
      expect(example.size).to eq(1)
      expect(example.map(&:id)).to eq(['1'])
    end

    it "allows multiple attributes in an intersect filter" do
      create_example(:id => '1', :name => 'Jane Doe', :email => 'jdoe@example.com',
        :active => 'true')
      create_example(:id => '2', :name => 'John Smith',
        :email => 'jsmith@example.com', :active => 'false')
      create_example(:id => '3', :name => 'Fred Bloggs',
        :email => 'fbloggs@example.com', :active => 'true')

      example = Zermelo::InfluxDBExample.intersect(:active => true,
        :name => 'Jane Doe').all
      expect(example).not_to be_nil
      expect(example).to be_an(Array)
      expect(example.size).to eq(1)
      expect(example.map(&:id)).to eq(['1'])
    end

    it "chains an intersect and a union filter together" do
      create_example(:id => '1', :name => 'Jane Doe', :email => 'jdoe@example.com',
        :active => 'true')
      create_example(:id => '2', :name => 'John Smith',
        :email => 'jsmith@example.com', :active => 'false')
      create_example(:id => '3', :name => 'Fred Bloggs',
        :email => 'fbloggs@example.com', :active => 'false')

      example = Zermelo::InfluxDBExample.intersect(:active => true).union(:name => 'Fred Bloggs').all
      expect(example).not_to be_nil
      expect(example).to be_an(Array)
      expect(example.size).to eq(2)
      expect(example.map(&:id)).to contain_exactly('3', '1')
    end

    it "chains an intersect and a diff filter together" do
      create_example(:id => '1', :name => 'Jane Doe', :email => 'jdoe@example.com',
        :active => 'true')
      create_example(:id => '2', :name => 'John Smith',
        :email => 'jsmith@example.com', :active => 'false')
      create_example(:id => '3', :name => 'Fred Bloggs',
        :email => 'fbloggs@example.com', :active => 'false')

      example = Zermelo::InfluxDBExample.intersect(:active => false).diff(:name => 'Fred Bloggs').all
      expect(example).not_to be_nil
      expect(example).to be_an(Array)
      expect(example.size).to eq(1)
      expect(example.map(&:id)).to eq(['2'])
    end

  end

  context 'has_many association' do

    it "sets a parent/child has_many relationship between two records in influxdb" do
      create_example(:id => '8', :name => 'John Jones',
                     :email => 'jjones@example.com', :active => 'true')
      example = Zermelo::InfluxDBExample.find_by_id('8')

      child = Zermelo::InfluxDBChild.new(:id => '3', :name => 'Abel Tasman')
      expect(child.save).to be_truthy

      children = example.children.all

      expect(children).to be_an(Array)
      expect(children).to be_empty

      example.children << child

      children = example.children.all

      expect(children).to be_an(Array)
      expect(children.size).to eq(1)
    end

    it "applies an intersect filter to a has_many association" do
      create_example(:id => '8', :name => 'John Jones',
                     :email => 'jjones@example.com', :active => 'true')
      example = Zermelo::InfluxDBExample.find_by_id('8')

      child_1 = Zermelo::InfluxDBChild.new(:id => '3', :name => 'John Smith')
      expect(child_1.save).to be_truthy

      child_2 = Zermelo::InfluxDBChild.new(:id => '4', :name => 'Jane Doe')
      expect(child_2.save).to be_truthy

      example.children.add(child_1, child_2)
      expect(example.children.count).to eq(2)

      result = example.children.intersect(:name => 'John Smith').all
      expect(result).to be_an(Array)
      expect(result.size).to eq(1)
      expect(result.map(&:id)).to eq(['3'])
    end

    it "applies chained intersect and union filters to a has_many association" do
      create_example(:id => '8', :name => 'John Jones',
                     :email => 'jjones@example.com', :active => 'true')
      example = Zermelo::InfluxDBExample.find_by_id('8')

      child_1 = Zermelo::InfluxDBChild.new(:id => '3', :name => 'John Smith')
      expect(child_1.save).to be_truthy

      child_2 = Zermelo::InfluxDBChild.new(:id => '4', :name => 'Jane Doe')
      expect(child_2.save).to be_truthy

      example.children.add(child_1, child_2)
      expect(example.children.count).to eq(2)

      result = example.children.intersect(:name => 'John Smith').union(:id => '4').all
      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result.map(&:id)).to eq(['3', '4'])
    end

  end

end
