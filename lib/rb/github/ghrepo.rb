# -*- coding: UTF-8 -*-

require "openssl"
require "octokit"
require "gender_detector"
require "geokit"
require "silent"
require "json"

fail "Set DATATOOLS_GH_TOKEN" unless ENV["DATATOOLS_GH_TOKEN"]

CLIENT = Octokit::Client.new(:access_token => ENV["DATATOOLS_GH_TOKEN"])
CLIENT.auto_paginate = true

GENDER_DETECTOR = GenderDetector.new

GEOCODER = Geokit::Geocoders::MultiGeocoder

class EmptyLocation
  def city; nil; end
  def country; nil; end
end

class Contributor
  def initialize login
    @login = login
  end

  def attrs
    @attrs || @attrs = CLIENT.user(@login).to_h
  end

  def first_name
    @first_name || @first_name = _first_name
  end

  def gender
    return unless first_name
    GENDER_DETECTOR.get_gender first_name
  end

  def city
    location.city
  end

  def country
    location.country
  end

  def location
    return EmptyLocation.new unless attrs.has_key? :location
    # the geocoder logs errors when it can't find a location. We don't want
    # that.
    @location || @location = silent(:stdout, :stderr) do
        GEOCODER.geocode(attrs[:location]) || EmptyLocation.new
    end
  rescue
    # avoid any error
    EmptyLocation.new
  end

  def report
    r = {}
    %i[first_name gender city country].each do |m|
      r[m] = send(m)
    end

    %i[login id site_admin name company blog email hireable bio public_repos
       public_gists followers following created_at].each do |a|
      r[a] = attrs[a]
    end

    r
  end

  def inspect
    "#<Contributor:\"#{@login}\">"
  end

  private

  def _first_name
    name = attrs[:name]
    return unless name && !name.empty?

    fn = name.split(" ")[0]
    fn =~ /^[A-Z]\.$/ ? nil : fn
  end
end

class Repo
  def initialize name
    @name = name
    @repo = CLIENT.repository name
  end

  def contributors
    CLIENT.contributors(@name).map { |c| Contributor.new c[:login] }
  end

  def report
    r = {}
    attrs = @repo.attrs
    %i[created_at description forks_count open_issues_count pushed_at
       stargazers_count subscribers_count watchers_count full_name].each do |m|
      r[m] = attrs[m]
    end

    r[:contributors] = contributors.map(&:report)

    r
  end

  def to_json
    report.to_json
  end

  def inspect
    "#<Repo:\"#{@name}\">"
  end
end
