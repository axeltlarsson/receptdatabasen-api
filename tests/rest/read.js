import { rest_service, resetdb } from '../common'
import should from 'should'

describe('read', function () {
  before(function (done) { resetdb(); done() })
  after(function (done) { resetdb(); done() })

  it('basic', function (done) {
    rest_service()
      .get('/recipes?select=id,title')
      .expect('Content-Type', /json/)
      .expect(200, done)
      .expect(r => {
        r.body.length.should.equal(7)
        r.body[0].id.should.equal(1)
      })
  })

  it('by primary key', function (done) {
    rest_service()
      .get('/recipes/1?select=id,title')
      .expect(200, done)
      .expect(r => {
        r.body.id.should.equal(1)
        r.body.title.should.equal('Cheese Cake')
      })
  })
})
